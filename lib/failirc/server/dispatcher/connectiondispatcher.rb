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

module IRC; class Server; class Dispatcher

class ConnectionDispatcher
  extend Forwardable

  class Connections
    class Things < CaseInsensitiveHash
      def initialize
        @sockets = Hash.new
      end

      alias __get__ []
      alias __set__ []=
      alias __del__ delete

      def [] (what)
        if what.is_a?(String) || what.is_a?(Symbol)
          __get__(what)
        else
          @sockets[what]
        end
      end

      def []= (what, value)
        if what.is_a?(Incoming)
          __set__(what.to_s, value)
          @sockets[what.socket] = value
        else
          @sockets[what] = value
        end
      end

      def delete (what)
        if what.is_a?(String) || what.is_a?(Symbol)
          @sockets.delete(__del__(what).socket)
        else
          __del__(@sockets.delete(what).to_s)
        end
      end

      def sockets
        @sockets.keys
      end
    end

    class Server
      attr_reader :socket, :config, :context

      def initialize (socket, config, context)
        @socket  = socket
        @config  = config
        @context = context
      end
    end

    attr_reader :server, :listening, :things, :clients, :servers
  
    def initialize (server)
      @server = server
  
      @listening = []
      @things  = Things.new
      @clients = Things.new
      @servers = Things.new
    end
  
    def empty?
      sockets.empty?
    end
  
    def exists? (socket)
      !!things[socket]
    end
  
    def delete (socket)
      return unless exists?(socket)

      thing = @things[socket]
  
      if thing.is_a?(Client)
        @clients.delete(thing.to_s)
      elsif thing.is_a?(Server)
        @servers.delete(thing.to_s)
      end
  
      @things.delete(socket)
    end

    def thing (identifier)
      if identifier.is_a?(Client) || identifier.is_a?(Server)
        return identifier
      elsif identifier.is_a?(User)
        return identifier.client
      else
        return @things[identifier]
      end
    end
  end

  class Data
    attr_reader :server

    def initialize (server)
      @server = server
      @data   = ThreadSafeHash.new
    end

    def [] (socket)
      if socket.is_a?(Client) || socket.is_a?(User) || socket.is_a?(Server)
        socket = socket.socket
      end

      (@data[socket] ||= [])
    end

    def push (socket, string)
      if string == :EOC
        if !socket.is_a?(TCPSocket) && !socket.is_a?(OpenSSL::SSL::SSLSocket)
          socket = socket.socket rescue nil
        end

        if socket
          server.dispatcher.disconnecting.push(:thing => server.dispatcher.connections.things[socket], :output => self[socket])
        end
      else
        string.lstrip!
      end

      if (string && !string.empty?) || self[socket].last == :EOC
        self[socket].push(string)
      end
    end

    def pop (socket)
      self[socket].shift
    end

    def clear (socket)
      self[socket].clear
    end

    def delete (socket)
      @data.delete(socket)

      if socket.is_a?(Client) || socket.is_a?(User) || socket.is_a?(Server)
        @data.delete(socket.socket)
      end
    end

    def first (socket)
      self[socket].first
    end

    def last (socket)
      self[socket].last
    end

    def empty? (socket=nil)
      if socket
        if socket.is_a?(Client) || socket.is_a?(User)
          socket = socket.socket
        end

        if @data.has_key?(socket)
           return @data[socket].empty?
        else
          return true
        end
      else
        return @data.all? {|(name, data)|
          data.empty?
        }
      end
    end

    def each (&block)
      @data.each_key &block
    end
  end

  attr_reader :server, :connections, :input, :output, :disconnecting

  def initialize (server)
    @server        = server
    @connections   = Connections.new(server)
    @input         = Data.new(server)
    @output        = Data.new(server)
    @disconnecting = []
    @handling      = ThreadSafeHash.new
    @waiting       = ThreadSafeCounter.new

    ConnectionDispatcher.def_delegators :@connections, :sockets, :clients, :servers, :things
  end

  def listen (listen, options)
    server  = TCPServer.new(options[:bind], options[:port])
    context = nil

    if options[:ssl] != 'disabled'
      context = SSLUtils::context(options[:ssl_cert], options[:ssl_key])
    end

    @connections.listening.push(Connections::Server.new(server, listen, context))
  end

  def timeout
    if @input.empty? && @output.empty? && @waiting.to_i == 0
      nil
    elsif @waiting.to_i > 0
      0.1
    else
      0
    end
  end

  def do
    sockets = @connections.things.sockets

    begin
      reading, writing, erroring = IO::select((sockets + @connections.listening.map {|server| server.socket}), (@output.empty? ? nil : sockets), nil, timeout)
    rescue; ensure
      clean
    end
    
    if reading && !reading.empty?
      reading.each {|socket|
        if sockets.member?(socket)
          read socket
        else
          @waiting.increment
          accept socket
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

        thing.data[:quitting] = true

        case thing
          when Client
            thing.channels.each_value {|channel|
              channel.users.delete(thing.nick)
            }

          when Server
        end

        @input.delete(thing)
        @output.delete(thing)

        @connections.delete(thing.socket)
    
        IRC.debug "#{thing.inspect} disconnected."

        thing.socket.close rescue nil

        @disconnecting.delete(data)
      end
    }

    (@connections.clients.sockets + @connections.servers.sockets).each {|socket|
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
      @waiting.decrement
      return
    end

    Thread.new {
      begin
        if server.config['ssl'] == 'enabled'
          ssl = OpenSSL::SSL::SSLSocket.new socket, server.context

          timeout self.server.config.xpath('config/server/timeout').first.text.to_i do
            ssl.accept
          end

          socket = ssl
        end

        @connections.things[socket] = Incoming.new(self.server, socket, server.config)

        self.server.fire(:connection, @connections.things[socket])
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
        @waiting.decrement
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
            ap string

            server.dispatcher.dispatch(:input, @connections.thing(socket), string)
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
