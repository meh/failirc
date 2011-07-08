# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.doesntexist.org | meh@paranoici.org]
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

require 'thread'
require 'socket'
require 'openssl'

begin
  OpenSSL::SSL::SSLSocket.instance_method :read_nonblock
rescue Exception => e
  require 'openssl/nonblock'
end

require 'failirc/utils'
require 'failirc/sslutils'

require 'failirc/client/server'

module IRC

class Client

class Dispatcher

class ConnectionDispatcher
    class Connections
        attr_reader :client
    
        def initialize (client)
            @client = client
    
            @data           = ThreadSafeHash.new
            @data[:sockets] = []
            @data[:servers] = {
                :bySocket => {},
                :byName   => {},
            }
        end
    
        def sockets
            @data[:sockets]
        end
    
        def servers
            @data[:servers]
        end
    
        def empty?
            sockets.empty?
        end
    
        def exists? (socket)
            servers[:bySocket][socket] ? true : false
        end
    
        def delete (socket)
            if !exists?(socket)
                return
            end

            @data[:sockets].delete(socket)

            server = @data[:servers][:bySocket][socket]
            @data[:servers][:bySocket].delete(socket)
            @data[:servers][:byName].delete(server.name)
        end
    end

    class Data
        attr_reader :client, :dispatcher

        def initialize (dispatcher)
            @client     = dispatcher.client
            @dispatcher = dispatcher

            @data = ThreadSafeHash.new
        end

        def [] (socket)
            if socket.is_a?(Server)
                socket = socket.socket
            end

            if !@data[socket].is_a?(Array)
                @data[socket] = []
            end

            @data[socket]
        end

        def push (socket, string)
            if string.is_a?(String)
                string.lstrip!
            end

            if string == :EOC
                if socket.is_a?(Server)
                    socket = socket.socket
                end

                dispatcher.disconnecting.push({ :server => client.server(socket), :output => self[socket] })
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
            if socket.is_a?(Server)
                socket = socket.socket
            end

            @data.delete(socket)
        end

        def first (socket)
            self[socket].first
        end

        def last (socket)
            self[socket].last
        end

        def empty? (socket=nil)
            if socket
                if socket.is_a?(Server)
                    socket = socket.socket
                end

                if @data.has_key?(socket)
                   return @data[socket].empty?
                else
                    return true
                end
            else
                return @data.empty?
            end
        end

        def each (&block)
            @data.each_key &block
        end
    end

    attr_reader :client, :dispatcher, :connections, :input, :output, :disconnecting

    def initialize (dispatcher)
        @client     = dispatcher.client
        @dispatcher = dispatcher

        @connections   = Connections.new(client)
        @input         = Data.new(dispatcher)
        @output        = Data.new(dispatcher)
        @disconnecting = []
        @reconnecting  = []
    end

    def sockets
        @connections.sockets
    end

    def servers
        @connections.servers
    end

    def connect (options, config, name=nil)
        Thread.new {
            socket  = nil
            context = nil
    
            begin
                socket = TCPSocket.new(options[:host], options[:port])
            rescue Errno::ECONNREFUSED
                self.debug "Could not connect to #{options[:host]}/#{options[:port]}."
                return
            end
    
            if options[:ssl] != 'disabled'
                context = SSLUtils::context(options[:ssl_cert], options[:ssl_key])
            end
    
            host = socket.peeraddr[2]
            ip   = socket.peeraddr[3]
            port = socket.peeraddr[1]
    
            self.debug "Connecting to #{host}[#{ip}/#{port}]"
    
            begin
                if config.attributes['ssl'] != 'disabled'
                    ssl = OpenSSL::SSL::SSLSocket.new socket, context
    
                    ssl.connect
                    socket = ssl
                end
    
                @connections.servers[:bySocket][socket] = Server.new(client, socket, config, name)
                @connections.servers[:byName][server(socket).name] = server socket
                @connections.sockets.push(socket)
    
                if config.attributes['password']
                    server(socket).password = config.attributes['password']
                end
    
                @input[socket]
                
                dispatcher.execute :connect, @connections.servers[:bySocket][socket]
            rescue OpenSSL::SSL::SSLError
                self.debug "Tried to connect to #{host}[#{ip}/#{port}] with SSL but the handshake failed."
                socket.close rescue nil
            rescue Errno::ECONNRESET
                socket.close rescue nil
                self.debug "#{host}[#{ip}/#{port}] connection reset."
            rescue Exception => e
                socket.close rescue nil
                self.debug e
            end
        }
    end

    def read (timeout=0.1)
        begin
            reading, = IO::select @connections.sockets, nil, nil, timeout
        rescue IOError
            @connections.sockets.each {|socket|
                if socket.closed?
                    kill server socket
                end
            }
        rescue Exception => e
            self.debug e
        end

        if !reading
            return
        end

        reading.each {|socket|
            server = self.server socket

            begin
                input = socket.read_nonblock 2048

                if !input || input.empty?
                    raise Errno::EPIPE
                end

                input.split(/[\r\n]+/).each {|string|
                    @input.push(socket, string)
                }
            rescue IOError
                disconnect server, 'Input/output error'
            rescue Errno::EBADF, Errno::EPIPE, OpenSSL::SSL::SSLError
                disconnect server, 'Client exited'
            rescue Errno::ECONNRESET
                disconnect server, 'Connection reset by peer'
            rescue Errno::ETIMEDOUT
                disconnect server, 'Ping timeout'
            rescue Errno::EHOSTUNREACH
                disconnect server, 'No route to host'
            rescue Errno::EAGAIN, IO::WaitReadable
            rescue Exception => e
                self.debug e
            end
        }
    end

    def disconnect (server, message=nil)
        @dispatcher.execute(:disconnect, server, message) rescue nil

        self.write

        @input.delete(server.socket)
        @output.delete(server.socket)
        connections.delete(server.socket)

        self.debug "Disconnected from #{server}[#{server.ip}/#{server.port}]"

        server.socket.close rescue nil

    end

    def clean
        @disconnecting.each {|server|
            disconnect server
        }
    end

    def handle
        @input.each {|socket|
            if dispatcher.event.handling[socket] || @input.empty?(socket)
                next
            end

            Thread.new {
                begin
                    if string = @input.pop(socket)
                        dispatcher.dispatch(:input, server(socket), string)
                    end
                rescue Exception => e
                    self.debug e
                end
            }
        }
    end

    def write (timeout=0)
        begin
            none, writing = IO::select nil, @connections.sockets, nil, timeout
        rescue IOError
            @connections.sockets.each {|socket|
                if socket.closed?
                    kill server socket
                end
            }
        rescue Exception => e
            self.debug e
        end

        if !writing
            return
        end

        writing.each {|socket|
            if @output.empty?(socket)
                next
            end

            server = self.server socket

            begin
                while !@output.empty?(socket)
                    output = @output.first(socket)

                    if output == :EOC
                        @disconnecting.push({
                            :server => server,
                            :output => @output[server]
                        })
                    else
                        output.force_encoding 'ASCII-8BIT'
                        socket.write_nonblock "#{output}\r\n"

                        @output.pop(socket)
                    end
                end
            rescue IOError
                disconnect server, 'Input/output error'
            rescue Errno::EBADF, Errno::EPIPE, OpenSSL::SSL::SSLError
                disconnect server, 'Client exited'
            rescue Errno::ECONNRESET
                disconnect server, 'Connection reset by peer'
            rescue Errno::ETIMEDOUT
                disconnect server, 'Ping timeout'
            rescue Errno::EHOSTUNREACH
                disconnect server, 'No route to host'
            rescue Errno::EAGAIN, IO::WaitWritable
            rescue Exception => e
                self.debug e
            end
        }
    end

    def finalize
        begin
            @connections.sockets.each {|socket|
                disconnect self.server(socket)
            }
        rescue Exception => e
            self.debug e
        end
    end

    def server (identifier)
        if identifier.is_a?(Server)
            return identifier
        elsif identifier.is_a?(String)
            return @connections.servers[:byName][identifier]
        else
            return @connections.servers[:bySocket][identifier]
        end
    end

    def empty?
        @connections.servers[:byName].empty?
    end
end

end

end

end
