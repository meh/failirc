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

require 'failirc/utils'
require 'failirc/server/event'

module IRC

class EventDispatcher
    include Utils

    attr_reader :server, :aliases, :events

    def initialize (server)
        @server = server

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

    def dispatch (chain, thing, string)
        event = Event.new(self, chain, thing, string)

        result = string

        @events[:pre].each {|callback|
            cloned         = event.clone
            cloned.special = :pre

            tmp = callback.call(cloned, thing, string)

            if tmp == false
                return false
            elsif tmp.is_a?(String)
                string = result = tmp
            end

            if cloned.type && !cloned.same?(string)
                return dispatch(chain, thing, string)
            end
        }

        if event.type
            event.callbacks.each {|callback|
                begin
                    tmp = callback.call(thing, string)
                rescue Exception => e
                    self.debug e
                end
    
                if tmp == false
                    return false
                elsif tmp.is_a?(String)
                    string = result = tmp
    
                    if !event.same?(string)
                        return dispatch(chain, thing, string)
                    end
                end
            }
        elsif chain == :input
            @events[:default].each {|callback|
                cloned         = event.clone
                cloned.special = :default
    
                tmp = callback.call(cloned, thing, string)
    
                if tmp == false
                    return false
                elsif tmp.is_a?(String)
                    string = result = tmp
                end
    
                if cloned.type && !cloned.same?(string)
                    return dispatch(chain, thing, string)
                end
            }
        end

        @events[:post].each {|callback|
            cloned         = event.clone
            cloned.special = :post

            tmp = callback.call(cloned, thing, string)

            if tmp == false
                return false
            elsif tmp.is_a?(String)
                string = result = tmp
            end

            if cloned.type && !cloned.same?(string)
                return dispatch(chain, thing, string)
            end
        }

        return result
    end

    def execute (event, *args)
        if @events[:custom][event]
            @events[:custom][event].each {|callback|
                begin
                    callback.method.call(*args)
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
