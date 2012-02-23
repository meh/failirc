#! /usr/bin/env ruby
require 'socket'
require 'thread'
require 'openssl'
require 'optparse'
require 'failirc/version'
require 'failirc/common/utils'
require 'readline'
require 'colorb'

options = {}

OptionParser.new do |o|
	options[:verbose] = false
	options[:number]  = 1000
	options[:prefix]  = 'S_'
	options[:delay]   = 0

	o.on '-V', '--version' do
		puts "Fail IRC stress test #{IRC.version}"
		exit 0
	end

	o.on '-v', '--[no-]verbose' do |value|
		options[:verbose] = value
	end

	o.on '-n', '--number VALUE', Integer do |value|
		options[:number] = value
	end

	o.on '-s', '--server VALUE' do |value|
		options[:server] = value
	end

	o.on '-p', '--prefix VALUE' do |value|
		options[:prefix] = value
	end

	o.on '-d', '--delay VALUE', Float do |value|
		options[:delay] = value
	end
end.parse!

@input   = Queue.new
@sockets = Class.new(Array) {
	include Awakenable

	attr_reader :prefix, :server, :port, :number

	def initialize (prefix, server, number, delay)
		@prefix = prefix

		@server = server.match(/^(.*?):/)[1]
		@port   = server.match(/:(.*?)$/)[1].to_i

		@number = number
		@unique = 0
		@delay  = delay

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

	def spawn
		return if @spawning

		@spawning = true

		each {|s|
			delete(s) if (s.closed? rescue true)
		}

		to_spawn = @number - length + 1

		if to_spawn > 0
			Readline.puts "Spawning #{to_spawn} connections to #{@server}:#{@port}"

			1.upto(to_spawn) {
				socket = TCPSocket.new(@server, @port)

				name = "#{@prefix}#{@unique += 1}"
				socket.write_nonblock "NICK #{name}\r\nUSER #{name} #{name} #{name} :#{name}\r\n"

				push socket

				sleep @delay
				wake_up
			}
		end

		@spawning = false
	end
}.new(options[:prefix], options[:server], options[:number], options[:delay])

COMMANDS = {
	/^PING(.+)$/ => lambda {|match|
		write("PONG#{match[1]}\r\n")
	}
}

thread = Thread.new {
	loop do
		Thread.new {
			begin;
				@sockets.spawn
			rescue Exception => e
				IRC.debug(e)
			end
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

module Readline
	Commands = ['!exit', '!quit', '!clients']
	Prefix   = '>> '.bold

	def self.supported?
		require 'colorb'
		require 'readline'

		true
	rescue Exception => e
		false
	end

	if supported?
		self.completion_proc = proc {|s|
			next unless s.start_with?('!')

			Commands.grep(/^#{Regexp.escape(s)}/)
		}
	end

	def self.puts (text)
		print "\r#{text}#{' ' * (Readline.get_screen_size.last - text.length - 1)}\n"
		print Prefix
	end

	def self.readline_with_hist_management
		begin
			line = Readline.readline(Prefix, true)
		rescue Exception => e
			return
		end

		return unless line

		if line =~ /^\s*$/ or Readline::HISTORY.to_a[-2] == line
			Readline::HISTORY.pop
		end

		line
	end
end

if Readline.supported?
	while line = Readline.readline_with_hist_management

		if line.start_with?('!')
			case line[1 .. -1]
				when 'exit', 'quit'
					exit!

				when /^clients\s+(.*)$/
					next if $1.to_i == 0

					@sockets.number = $1.to_i
					@sockets.wake_up
			end
		else
			@input.push eval("%{#{line}}")
			@sockets.wake_up
		end
	end
else
	thread.join
end
