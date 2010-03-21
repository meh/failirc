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

require 'thread'
require 'socket'
require 'openssl/nonblock'

require 'failirc/utils'
require 'failirc/sslutils'

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
            server[socket] ? true : false
        end
    
        def delete (socket)
            if !exists?(socket)
                return
            end

            @data[:sockets].delete(socket)

            server = @data[:servers][:bySocket][socket]
            @data[:servers][:bySocket].delete(socket)
            @data[:servers][:byName].delete(server.name)
    
            socket.close rescue nil
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
                if socket.is_a?(Client) || socket.is_a?(User)
                    socket = socket.socket
                end

                dispatcher.disconnecting.push({ :thing => dispatcher.connections.things[socket], :output => self[socket] })
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
    end

    def sockets
        @connections.sockets
    end

    def servers
        @connections.servers
    end

    def connect (options, config)
        server  = TCPSocket.new(Resolv.getaddress(options[:address]), options[:port])
        context = nil

        if options[:ssl] != 'disabled'
            context = SSLUtils::context(options[:ssl_cert], options[:ssl_key])
        end

        self.debug "Connecting to #{server.peeraddr[2]}[#{server.peeraddr[3]}/#{server.peeraddr[1]}]"

        begin
            if listen.attributes['ssl'] != 'disabled'
                ssl = OpenSSL::SSL::SSLSocket.new server, context

                ssl.connect
                server = ssl
            end

            @connections.servers[:bySocket][server] = Client::Server.new(client, server, config)

            @connections.servers[:byName][@connections.servers[:bySocket][server].name]
                = @connections.servers[:bySocket][server]

            @connections.sockets.push(server)

            @input[server]
        rescue OpenSSL::SSL::SSLError
            self.debug "Tried to connect to #{server.peeraddr[3]}/#{server.peeraddr[1]} with SSL bubt the handshake failed."
            server.close rescue nil
        rescue Errno::ECONNRESET
            server.close rescue nil
            self.debug "#{server.peeraddr[2]}[#{server.peeraddr[3]}] connection reset."
        rescue Exception => e
            server.close rescue nil
            self.debug e
        end
    end

    def read (timeout=0.1)
        begin
            reading, = IO::select @connections.sockets, nil, nil, timeout
        rescue Exception => e
            self.debug e
        end

        if !reading
            return
        end

        reading.each {|socket|
            server = @connections.servers[:bySocket][socket]

            begin
                input = socket.read_nonblock 2048

                if !input || input.empty?
                    raise Errno::EPIPE
                end

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
                self.debug e
            end
        }
    end

    def clean
        @disconnecting.each {|data|
            thing  = data[:thing]
            output = data[:output]

            if output.first == :EOC
                output.shift
                handleDisconnection thing, output.shift
                @disconnecting.delete(data)
            end
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
                        dispatcher.dispatch(:input, @connections.things[socket], string)
                    end
                rescue Exception => e
                    self.debug e
                end
            }
        }
    end

    def write (timeout=0)
        begin
            none, writing, erroring = IO::select nil, @connections.sockets, nil, timeout
        rescue Exception => e
            self.debug e
        end

        if erroring
            erroring.each {|socket|
                thing = @connections.things[socket]

                server.kill thing, 'Client exited', true

                @output.pop(socket)
                handleDisconnection thing, @output.pop(socket)
            }
        end

        if !writing
            return
        end

        writing.each {|socket|
            if @output.empty?(socket)
                next
            end

            thing = @connections.things[socket]

            begin
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
                self.debug e
            end
        }
    end

    def handleDisconnection (server, message)
        @dispatcher.execute(:disconnect, server, message) rescue nil

        @output.delete(server.socket)
        connections.delete(server.socket)

        self.debug "Disconnected from #{server}[#{server.socket.peeraddr[3]}/#{server.socket.peeraddr[1]}]"

        server.socket.close rescue nil
    end

    def finalize
        begin
            @connections.listening[:sockets].each {|server|
                server.close
            }

            @clients.each {|key, client|
                kill client, 'Good night sweet prince.'
            }

            @links.each {|key, link|
                kill client, 'Good night sweet prince.'
            }
        rescue Exception => e
            self.debug e
        end
    end
end

end

end

end
