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
require 'failirc/extensions'
require 'failirc/utils'
require 'failirc/server/event'

module IRC

class Dispatcher
    include Utils

    class Input < ThreadSafeHash
        def initialize
            super()
        end

        def start (chain, deep, socket)
            if !deep && chain == :input
                self[socket] = true
            end
        end

        def stop (chain, deep, socket)
            if !deep && chain == :input
                self[socket] = false
            end
        end

        def handling? (socket)
            self[socket]
        end
    end

    class Output < Hash
        def initialize
            @handling = ThreadSafeHash.new

            super()
        end

        alias __get []

        def [] (socket)
            if !__get(socket)
                self[socket] = Queue.new
            end

            return __get(socket)
        end

        def push (socket, text)
            self[socket].push(text)
        end

        def pop (socket)
            self[socket].pop(true) rescue nil
        end

        def flush (socket)
            if @handling[socket]
                return
            end

            @handling[socket] = true
            
            while out = pop(socket)
                socket.puts out
            end

            @handling[socket] = false
        end
    end

    attr_reader :server, :output, :handling, :aliases, :events

    def initialize (server)
        @server = server

        @input  = Input.new
        @output = Output.new

        @aliases = {
            :input  => {},
            :output => {},
        }

        @events = {
            :pre     => [],
            :post    => [],
            :default => [],

            :custom => {},

            :input  => {},
            :output => {},
        }
    end

    def loop
        while !server.stopping?
            if server.connections.empty?
                sleep 2
                next
            end

            begin
                reading, = IO::select server.connections[:sockets], nil, nil, 2

                if reading
                    reading.each {|socket|
                        thing = server.connections[:things][socket]

                        if @input.handling?(socket)
                            next
                        end

                        Thread.new {
                            begin
                                string = socket.gets

                                if !string || string.empty?
                                    raise Errno::EPIPE
                                else
                                    if !string.strip!.empty?
                                        dispatch :input, thing, string
                                    end
                                end
                            rescue IOError, Errno::EBADF, Errno::EPIPE
                                server.kill thing, 'Client exited.'
                            rescue Errno::ECONNRESET
                                server.kill thing, 'Connection reset by peer.'
                            rescue Exception => e
                                debug e
                            end
                        }
                    }
                end
            rescue IOError, Errno::EBADF, Errno::EPIPE, Errno::ECONNRESET
            rescue Exception => e
                self.debug e
            end
        end
    end

    def dispatch (chain, thing, string, deep=false)
        if !thing
            return
        end

        @input.start(chain, deep, thing.socket)

        event  = Event.new(self, chain, thing, string)
        result = string

        @events[:pre].each {|callback|
            event.special = :pre

            if callback.call(event, thing, string) == false
                @input.stop(chain, deep, thing.socket)
                return false
            end

            if event.type && !event.same?(string)
                result = dispatch(chain, thing, string, true)

                @input.stop(chain, deep, thing.socket)

                return result
            end
        }

        if event.type
            event.special = nil

            event.callbacks.each {|callback|
                begin
                    if callback.call(thing, string) == false
                        @input.stop(chain, deep, thing.socket)
                        return false
                    end
                rescue Exception => e
                    self.debug e
                end
    
                if !event.same?(string)
                    result = dispatch(chain, thing, string, true)

                    @input.stop(chain, deep, thing.socket)

                    return result
                end
            }
        elsif chain == :input
            @events[:default].each {|callback|
                event.special = :default
    
                if callback.call(event, thing, string) == false
                    @input.stop(chain, deep, thing.socket)
                    return false
                end
    
                if event.type && !event.same?(string)
                    result = dispatch(chain, thing, string, true)

                    if !deep && chain == :input
                        @handling[thing.socket] = false
                    end

                    return result
                end
            }
        end

        @events[:post].each {|callback|
            event.special = :post

            if callback.call(event, thing, string) == false
                @input.stop(chain, deep, thing.socket)
                return false
            end

            if event.type && !event.same?(string)
                result = dispatch(chain, thing, string, true)

                @input.stop(chain, deep, thing.socket)

                return result
            end
        }

        @input.stop(chain, deep, thing.socket)

        return result
    end

    def execute (event, *args)
        if @events[:custom][event]
            @events[:custom][event].each {|callback|
                begin
                    if callback.method.call(*args) == false
                        return false
                    end
                rescue Exception => e
                    self.debug(e)
                end
            }
        end
    end

    def alias (chain, symbol, regex)
        if !regex
            @aliases[chain].delete(symbol)
        elsif !regex.class == Regexp
            raise 'You have to alias to a Regexp.'
        else
            @aliases[chain][symbol] = regex
        end
    end

    def register (chain, type, callback, priority=0)
        if !type
            events = @events[chain]

            if !events
                events = @events[chain] = []
            end
        else
            if @aliases[chain]
                if @aliases[chain][type]
                    type = @aliases[chain][type]
                end
            end

            if !@events[chain]
                @events[chain] = {}
            end

            events = @events[chain][type]

            if !events
                events = @events[chain][type] = []
            end
        end

        if !callback
            events.clear
        elsif callback.is_a?(Array)
            callback.each {|callback|
                register(chain, type, callback)
            }
        else
            if callback.is_a?(Event::Callback)
                events.push(callback)
            else
                events.push(Event::Callback.new(callback, priority))
            end
        end

        events.sort! {|a, b|
            a.priority <=> b.priority
        }
    end
end

end
