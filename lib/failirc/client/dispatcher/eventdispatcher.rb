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

require 'failirc/utils'
require 'failirc/client/dispatcher/event'

module IRC

class Client

class Dispatcher

class EventDispatcher
    attr_reader :client, :dispatcher, :handling, :aliases, :events

    def initialize (dispatcher)
        @client     = dispatcher.client
        @dispatcher = dispatcher
        @handling   = ThreadSafeHash.new

        @aliases = newAliases
        @events  = newEvents
    end

    def newAliases
        Hash[
            :input  => {},
            :output => {},
        ]
    end

    def newEvents
        Hash[
            :pre     => [],
            :post    => [],
            :default => [],

            :custom => {},

            :input  => {},
            :output => {}
        ]
    end

    def handle (what, chain, deep, server)
        if chain != :input || deep
            return
        end

        if what == :start
            @handling[server.socket] = true
        else
            @handling.delete(server.socket)
        end
    end

    def dispatch (chain, server, string, deep=false)
        if !server
            return
        end

        handle(:start, chain, deep, server)

        event  = Event.new(self, chain, server, string)
        result = string

        @events[:pre].each {|callback|
            event.special = :pre

            if callback.call(event, server, string) == false
                handle(:stop, chain, deep, server)
                return false
            end
        }

        if !event.types.empty?
            event.special = nil

            event.callbacks.each {|callback|
                begin
                    if callback.call(server, string) == false
                        handle(:stop, chain, deep, server)
                        return false
                    end
                rescue Exception => e
                    self.debug e
                end
            }
        elsif chain == :input
            @events[:default].each {|callback|
                event.special = :default
    
                if callback.call(event, server, string) == false
                    handle(:stop, chain, deep, server)
                    return false
                end
            }
        end

        @events[:post].each {|callback|
            event.special = :post

            if callback.call(event, server, string) == false
                handle(:stop, chain, deep, server)
                return false
            end
        }

        handle(:stop, chain, deep, server)

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
                    self.debug e
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

end

end
