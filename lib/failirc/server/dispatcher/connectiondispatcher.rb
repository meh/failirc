#--
# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.doesntexist.org | meh.ffff@gmail.com]
#
# This file is part of failirc.
#
# failirc is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# failirc is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with failirc. If not, see <http://www.gnu.org/licenses/>.
#++

require 'forwardable'
require 'versionomy'
require 'thread'
require 'socket'
require 'timeout'

if Versionomy.parse(RUBY_VERSION) < Versionomy.parse('1.9.2')
  require 'openssl/nonblock'
end

require 'failirc/utils'
require 'failirc/sslutils'

require 'failirc/server/incoming'

require 'failirc/server/dispatcher/connections'
require 'failirc/server/dispatcher/data'

module IRC; class Server; class Dispatcher

class ConnectionDispatcher
  extend Forwardable

  attr_reader :server, :connections, :input, :output, :disconnecting

  def initialize (server)
    @server        = server
    @pipes         = IO.pipe
    @connections   = Connections.new(server)
    @input         = Data.new(server)
    @output        = Data.new(server)
    @disconnecting = []
    @handling      = ThreadSafeHash.new

    ConnectionDispatcher.def_delegators :@connections, :sockets, :things
  end

  def wakeup
    @pipes.last.write 'x'
  end

  def listen (options)
    server  = TCPServer.new(options['bind'], options['port'])
    context = nil

    if options['ssl']
      context = SSLUtils::context(options['ssl']['cert'], options['ssl']['key'])
    end

    @connections.listening.push(Connections::Server.new(server, options, context))
    wakeup
  end

  def do
    sockets = @connections.sockets

    begin
      reading, writing, erroring = IO::select(([@pipes.first] + sockets + @connections.listening.map {|server| server.socket}), (@output.empty? ? nil : sockets))
    rescue; ensure
      clean
    end
    
    if reading && !reading.empty?
      reading.each {|socket|
        if socket == @pipes.first
          @pipes.first.read_nonblock 2048
        else
          if sockets.member?(socket)
            read socket
          else
            accept socket
          end
        end
      }
    end

    handle

    if writing && !writing.empty?
      writing.each {|socket|
        write socket
      }
    end
  end

  def clean
    @disconnecting.each {|data|
      thing  = data[:thing]
      output = data[:output]

      if output.first == :EOC
        output.shift

        self.server.fire(:killed, thing, output.shift)

        thing.data.quitting = true

        @input.delete(thing)
        @output.delete(thing)

        @connections.delete(thing.socket)
    
        IRC.debug "#{thing.inspect} disconnected."

        thing.socket.close rescue nil

        @disconnecting.delete(data)

        wakeup
      end
    }

    @connections.sockets.each {|socket|
      if socket.closed?
        self.server.kill socket
      end
    }

    @connections.listening.delete_if {|server|
      server.socket.closed?
    }
  end

  def accept (socket)
    server = @connections.listening.find {|server| server.socket == socket}
    socket = socket.accept_nonblock

    begin
      host = socket.peeraddr[2]
      ip   = socket.peeraddr[3]
      port = socket.addr[1]

      IRC.debug "#{host}[#{ip}/#{port}] connecting."
    rescue
      IRC.debug "Someone (#{host}[#{ip}/#{port}]) failed to connect."
      return
    end

    Thread.new {
      begin
        if server.ssl?
          ssl = OpenSSL::SSL::SSLSocket.new socket, server.context

          timeout((self.server.options[:server][:timeout] || 15).to_i) do
            ssl.accept
          end

          socket = ssl
        end

        @connections << Incoming.new(self.server, socket, server.options)

        self.server.fire(:connection, @connections.thing(socket))
      rescue OpenSSL::SSL::SSLError, Timeout::Error
        socket.write_nonblock "This is a SSL connection, faggot.\r\n" rescue nil
        socket.close
        IRC.debug "#{host}[#{ip}/#{port}] tried to connect to a SSL connection and failed the handshake."
      rescue Errno::ECONNRESET
        socket.close
        IRC.debug "#{host}[#{ip}/#{port}] connection reset."
      rescue Exception => e
        socket.close
        IRC.debug e
      ensure
        wakeup
      end
    }
  end

  def read (socket)
    begin
      thing = @connections.thing(socket)
      input = socket.read_nonblock 2048

      raise Errno::EPIPE if !input || input.empty?

      input.split(/[\r\n]+/).each {|string|
        @input.push(socket, string)
      }
    rescue IOError
      server.kill thing, 'Input/output error', true
    rescue Errno::EBADF, Errno::EPIPE, OpenSSL::SSL::SSLError
      server.kill thing, 'Client exited', true
    rescue Errno::ECONNRESET
      server.kill thing, 'Connection reset by peer', true
    rescue Errno::ETIMEDOUT
      server.kill thing, 'Ping timeout', true
    rescue Errno::EHOSTUNREACH
      server.kill thing, 'No route to host', true
    rescue Errno::EAGAIN, IO::WaitReadable
    rescue Exception => e
      IRC.debug e
    end
  end

  def handle
    @input.each {|socket|
      next if @input.empty?(socket) || @handling[socket]

      @handling[socket] = true

      Thread.new {
        begin
          if string = @input.pop(socket)
            server.dispatcher.dispatch :input, @connections.thing(socket), string
          end
        rescue Exception => e
          IRC.debug e
        end

        @handling.delete(socket)
      }
    }
  end

  def write (socket)
    begin
      thing = @connections.thing(socket)

      while !@output.empty?(socket)
        output = @output.first(socket)

        if output == :EOC
          @output.delete(socket)
        else
          output.force_encoding 'ASCII-8BIT'
          socket.write_nonblock "#{output}\r\n"

          @output.pop(socket)
        end
      end
    rescue IOError
      server.kill thing, 'Input/output error', true
    rescue Errno::EBADF, Errno::EPIPE, OpenSSL::SSL::SSLError
      server.kill thing, 'Client exited', true
    rescue Errno::ECONNRESET
      server.kill thing, 'Connection reset by peer', true
    rescue Errno::ETIMEDOUT
      server.kill thing, 'Ping timeout', true
    rescue Errno::EHOSTUNREACH
      server.kill thing, 'No route to host', true
    rescue Errno::EAGAIN, IO::WaitWritable
    rescue Exception => e
      IRC.debug e
    end
  end
end

end; end; end
