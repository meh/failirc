# failirc, a fail IRC server.
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
require 'failirc/server/dispatcher/sslutils'

module IRC

class ConnectionDispatcher
    include Utils

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
        attr_reader :server

        def initialize (server)
            @server   = server
            @data     = ThreadSafeHash.new
            @handling = ThreadSafeHash.new
        end

        def push (socket, string)
            if socket.is_a?(Client) || socket.is_a?(User)
                socket = socket.socket
            end

            if !@data.has_key?(socket)
                @data[socket] = []
            end

            if string.is_a?(String)
                string.lstrip!
            end

            if (string && !string.empty?) || @data[socket].first == :EOC
                result = @data[socket].push(string)

                @handling[socket] = true
            end

            return result
        end

        def pop (socket)
            if socket.is_a?(Client) || socket.is_a?(User)
                socket = socket.socket
            end

            if !@data.has_key?(socket)
                @data[socket] = []
            end

            result = @data[socket].shift

            if @data[socket].empty?
                @handling.delete(socket)
            end

            return result
        end

        def delete (socket)
            if socket.is_a?(Client) || socket.is_a?(User)
                socket = socket.socket
            end

            @handling.delete(socket)

            return @data.delete(socket)
        end

        def first (socket)
            if socket.is_a?(Client) || socket.is_a?(User)
                socket = socket.socket
            end

            if !@data.has_key?(socket)
                @data[socket] = []
            end
           
            return @data[socket].first
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
                return @handling.empty?
            end
        end

        def each (&block)
            @data.each_key &block
        end
    end

    attr_reader :server, :dispatcher, :connections, :input, :output

    def initialize (dispatcher)
        @server     = dispatcher.server
        @dispatcher = dispatcher

        @connections = Connections.new(server)
        @input       = Data.new(server)
        @output      = Data.new(server)
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

        if options[:ssl]
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
        rescue 
        end
    end

    # Executed with each incoming connection
    def newConnection (socket, listen, context=nil)
        # here, somehow we should check if the incoming peer is a linked server or a real client

        Thread.new {
            begin
                if listen.attributes['ssl'] == 'enabled'
                    ssl = OpenSSL::SSL::SSLSocket.new socket, context
                    ssl.accept

                    socket = ssl
                end

                @connections.sockets.push(socket)
                @connections.things[socket] = @connections.clients[socket] = IRC::Client.new(server, socket, listen)
            rescue OpenSSL::SSL::SSLError
                socket.write_nonblock "This is a SSL connection, faggot.\r\n" rescue nil
                self.debug "#{socket.peeraddr[2]} tried to connect to a SSL connection and failed the handshake.", ''
                socket.close
            rescue Errno::ECONNRESET
                socket.close
            rescue Exception => e
                socket.close
                self.debug(e)
            end
        }
    end

    def read (timeout=0.1)
        begin
            reading, = IO::select @connections.sockets, nil, nil, timeout

            if reading
                reading.each {|socket|
                    thing = @connections.things[socket]

                    begin
                        input = String.new

                        begin
                            socket.read_nonblock 2048, input
                        rescue Errno::EAGAIN, IO::WaitReadable
                            if !input || input.empty?
                                raise Errno::EAGAIN
                            end
                        end

                        if !input || input.empty?
                            raise Errno::EPIPE
                        end

                        begin
                            if thing && thing.modes[:encoding]
                                input.force_encoding(thing.modes[:encoding])
                                input.encode!('UTF-8')
                            else
                                input.force_encoding('UTF-8')

                                if !input.valid_encoding?
                                    raise Encoding::InvalidByteSequenceError
                                end
                            end
                        rescue
                            if thing
                                if thing.modes[:encoding]
                                    dispatcher.execute :error, thing, 'The encoding you choose seems to not be the one you are using.'
                                else
                                    dispatcher.execute :error, thing, 'Please specify the encoding you are using with ENCODING <encoding>'
                                end
                            end

                            input.force_encoding('ASCII-8BIT')

                            input.encode!('UTF-8',
                                :invalid => :replace,
                                :undef   => :replace
                            )
                        end

                        input.split(/[\r\n]+/).each {|string|
                            @input.push(socket, string)
                        }
                    rescue IOError
                        server.kill thing, 'Input/output error'
                    rescue Errno::EBADF, Errno::EPIPE, OpenSSL::SSL::SSLError
                        server.kill thing, 'Client exited'
                    rescue Errno::ECONNRESET
                        server.kill thing, 'Connection reset by peer'
                    rescue Errno::ETIMEDOUT
                        server.kill thing, 'Ping timeout'
                    rescue Errno::EHOSTUNREACH
                        server.kill thing, 'No route to host'
                    rescue Errno::EAGAIN
                    rescue Exception => e
                        self.debug e
                    end
                }
            end
        rescue Exception => e
            self.debug e
        end
    end

    def handle
        @input.each {|socket|
            if dispatcher.event.handling[socket] || @input.empty?(socket)
                next
            end

            Thread.new {
                begin
                    string = @input.pop(socket)

                    if string
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
            none, writing = IO::select nil, @connections.sockets.map {|item| if !@output.empty?(item) then item end}.compact, nil, timeout

            if writing
                writing.each {|socket|
                    thing = @connections.things[socket]

                    if !thing
                        next
                    end

                    begin
                        while !@output.empty?(socket)
                            output = @output.first(socket)

                            if output == :EOC
                                @output.pop(socket)
                                message = @output.pop(socket)

                                @dispatcher.execute(:kill, thing, message)
        
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
                            
                                @output.delete(socket)
                                connections.delete(thing.socket)
        
                                socket.close
                            else
                                if thing.modes[:encoding]
                                    output.encode!(thing.modes[:encoding])
                                end

                                socket.write_nonblock "#{output}\r\n"

                                @output.pop(socket)
                            end
                        end
                    rescue IOError, Errno::EBADF, Errno::EPIPE, OpenSSL::SSL::SSLError
                        server.kill thing, 'Client exited'
                    rescue Errno::ECONNRESET
                        server.kill thing, 'Connection reset by peer'
                    rescue Errno::ETIMEDOUT
                        server.kill thing, 'Ping timeout'
                    rescue Errno::EHOSTUNREACH
                        server.kill thing, 'No route to host'
                    rescue Errno::EAGAIN, IO::WaitWritable
                    rescue Exception => e
                        self.debug e
                    end
                }
            end
        rescue Exception => e
            self.debug e
        end
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
