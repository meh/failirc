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

class Server

class Dispatcher

class ConnectionDispatcher
    class Connections
        attr_reader :server
    
        def initialize (server)
            @server = server
    
            @data = ThreadSafeHash.new
    
            @data[:listening] = {
                :sockets => [],
                :data    => {},
            }
    
            @data[:sockets] = []
            @data[:things]  = {}
            @data[:clients] = CaseInsensitiveHash.new
            @data[:links]   = CaseInsensitiveHash.new
        end
    
        def listening
            @data[:listening]
        end
    
        def sockets
            @data[:sockets]
        end
    
        def things
            @data[:things]
        end
    
        def clients
            @data[:clients]
        end
    
        def links
            @data[:links]
        end
    
        def empty?
            sockets.empty?
        end
    
        def exists? (socket)
            things[socket] ? true : false
        end
    
        def delete (socket)
            if !exists?(socket)
                return
            end

            thing = @data[:things][socket]
    
            if thing.is_a?(Client)
                @data[:clients].delete(thing.nick)
                @data[:clients].delete(socket)
            elsif thing.is_a?(Link)
                @data[:links].delete(thing.host)
                @data[:links].delete(socket)
            end
    
            @data[:sockets].delete(socket)
            @data[:things].delete(socket)
    
            socket.close rescue nil
        end
    end

    class Data
        attr_reader :server, :dispatcher

        def initialize (dispatcher)
            @server     = dispatcher.server
            @dispatcher = dispatcher

            @data = ThreadSafeHash.new
        end

        def [] (socket)
            if socket.is_a?(Client) || socket.is_a?(User)
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
            if socket.is_a?(Client) || socket.is_a?(User)
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
            if socket.is_a?(Client) || socket.is_a?(User)
                socket = socket.socket
            end

            if socket
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

    attr_reader :server, :dispatcher, :connections, :input, :output, :disconnecting

    def initialize (dispatcher)
        @server     = dispatcher.server
        @dispatcher = dispatcher

        @connections   = Connections.new(server)
        @input         = Data.new(dispatcher)
        @output        = Data.new(dispatcher)
        @disconnecting = []
    end

    def sockets
        @connections.sockets
    end

    def clients
        @connections.clients
    end

    def links
        @connections.links
    end

    def listen (options, listen)
        server  = TCPServer.new(options[:bind], options[:port])
        context = nil

        if options[:ssl] != 'disabled'
            context = SSLUtils::context(options[:ssl_cert], options[:ssl_key])
        end

        @connections.listening[:sockets].push(server)
        @connections.listening[:data][server] = { :listen => listen, :context => context }
    end

    def accept (timeout=0)
        begin
            listening, = IO::select @connections.listening[:sockets], nil, nil, timeout

            if listening
                listening.each {|server|
                    begin
                        socket, = server.accept_nonblock

                        if socket
                            newConnection socket, @connections.listening[:data][server][:listen], @connections.listening[:data][server][:context]
                        end
                    rescue Errno::EAGAIN
                    rescue Exception => e
                        self.debug e
                    end
                }
            end
        rescue IOError
            @connections.listening[:sockets].each {|socket|
                if socket.closed?
                    @connections.listening[:sockets].delete(socket)
                    @connections.listening[:data].delete(socket                 @connections.listening[:data].delete(socket))
                end
            }
        rescue
        end
    end

    # Executed with each incoming connection
    def newConnection (socket, listen, context=nil)
        # here, somehow we should check if the incoming peer is a linked server or a real client

        host = socket.peeraddr[2]
        ip   = socket.peeraddr[3]
        port = socket.addr[1]

        self.debug "#{host}[#{ip}/#{port}] connecting."

        Thread.new {
            begin
                if listen.attributes['ssl'] != 'disabled'
                    ssl = OpenSSL::SSL::SSLSocket.new socket, context

                    ssl.accept
                    socket = ssl
                end

                @connections.things[socket] = @connections.clients[socket] = Server::Client.new(server, socket, listen)
                @connections.sockets.push(socket)

                @input[socket]
            rescue OpenSSL::SSL::SSLError
                socket.write_nonblock "This is a SSL connection, faggot.\r\n" rescue nil
                self.debug "#{host}[#{ip}/#{port}] tried to connect to a SSL connection and failed the handshake."
                socket.close rescue nil
            rescue Errno::ECONNRESET
                socket.close rescue nil
                self.debug "#{host}[#{ip}/#{port}] connection reset."
            rescue Exception => e
                socket.close rescue nil
                self.debug(e)
            end
        }
    end

    def read (timeout=0.1)
        begin
            reading, = IO::select @connections.sockets, nil, nil, timeout
        rescue IOError
            @connections.sockets.each {|socket|
                if socket.closed?
                    server.kill socket
                end
            }
        rescue Exception => e
            self.debug e
        end

        if !reading
            return
        end

        reading.each {|socket|
            thing = thing socket

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
                        dispatcher.dispatch(:input, thing(socket), string)
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
        rescue IOError
            @connections.sockets.each {|socket|
                if socket.closed?
                    server.kill thing socket, 'Client exited'
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

            thing = thing socket

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

    def handleDisconnection (thing, message)
        @dispatcher.execute(:kill, thing, message) rescue nil

        if thing.is_a?(Client)
            thing.modes[:quitting] = true

            if thing.modes[:registered]
                thing.channels.each_value {|channel|
                    channel.users.delete(thing.nick)
                }
            end
        elsif thing.is_a?(Link)
            # wat
        end
    
        @output.delete(thing.socket)
        connections.delete(thing.socket)

        self.debug "#{thing.mask}[#{thing.ip}/#{thing.port}] disconnected."

        thing.socket.close rescue nil
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

    def thing (identifier)
        if identifier.is_a?(Client) || identifier.is_a?(Link)
            return identifier
        elsif identifier.is_a?(User)
            return identifier.client
        else
            return @connections.things[identifier]
        end
    end
end

end

end

end
