#! /usr/bin/env ruby
require 'socket'
require 'thread'
require 'failirc/version'
require 'failirc/common/utils'
require 'getoptlong'

args = GetoptLong.new(
  ['--version', '-v', GetoptLong::NO_ARGUMENT],
  ['--verbose', '-V', GetoptLong::NO_ARGUMENT],
  ['--number',  '-n', GetoptLong::REQUIRED_ARGUMENT],
  ['--server',  '-s', GetoptLong::REQUIRED_ARGUMENT],
  ['--prefix',  '-p', GetoptLong::REQUIRED_ARGUMENT]
)

options = {
  verbose: false,
  number:  1000,
  prefix:  'S_'
}

args.each {|option, value|
  case option
    when '--version'
      puts "Fail IRC stress test #{IRC.version}"
      exit 0

    when '--verbose'
      options[:verbose] = true

    when '--number'
      options[:number] = value.to_i

    when '--server'
      options[:server] = value

    when '--prefix'
      options[:prefix] = value
  end
}

def wakeup
  @pipes.last.write '?'
end

@input   = Queue.new
@sockets = Class.new(Array) {
  attr_reader :prefix, :server, :port, :number

  def initialize (prefix, server, number)
    @prefix = prefix

    @server = server.match(/^(.*?):/)[1]
    @port   = server.match(/:(.*?)$/)[1].to_i

    @number = number
    @unique = 0

    @pipes = IO.pipe

    self << @pipes.first
  end

  def number= (value)
    return if value == number

    if value < number
      tmp, @number = number, value

      slice!(tmp - value, length).each {|socket|
        socket.close
      }
    else
      @number = value
    end
  end

  def wakeup
    @pipes.last.write '?'
  end

  def spawn
    return if @spawning

    @spawning = true

    self.each {|s|
      self.delete(s) if (s.closed? rescue true)
    }

    to_spawn = @number - self.length + 1

    if to_spawn > 0
      puts "Spawning #{to_spawn} connections to #{@server}:#{@port}"

      1.upto(to_spawn) {
        socket = TCPSocket.new(@server, @port)

        name = "#{@prefix}#{@unique += 1}"
        socket.write_nonblock "NICK #{name}\r\nUSER #{name} #{name} #{name} :#{name}\r\n"

        self << socket

        wakeup
      }
    end

    @spawning = false
  end
}.new(options[:prefix], options[:server], options[:number])

COMMANDS = {
  /^PING(.+)$/ => lambda {|match|
    write("PONG#{match[1]}\r\n")
  }
}

Thread.new {
  loop do
    Thread.new {
      @sockets.spawn
    }

    begin
      reading, = IO.select(@sockets)
    rescue; next; end

    reading.each {|socket|
      if socket.class == IO
        socket.read_nonblock 2048
        next
      end

      line = socket.gets or socket.close && next

      COMMANDS.each {|regex, block|
        if matches = regex.match(line)
          begin
            socket.instance_exec matches, &block
          rescue Exception => e
            IRC.debug e
          end
        end
      }
    }

    unless @input.empty?
      line = @input.pop

      @sockets.each {|socket|
        next if socket.class == IO

        socket.write_nonblock line
      }
    end
  end
}

while (line = $stdin.gets) != 'exit'
  case line
    when /^send\s+(.*?)$/
      @input.push eval("%{#{$1}}")
      @sockets.wakeup

    when /^clients\s+(.*)$/
      @sockets.number = $1.to_i
      @sockets.wakeup

  end
end
