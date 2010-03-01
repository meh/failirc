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

require 'failirc/server/event'

module IRC

class EventDispatcher
    attr_reader :aliases, :events

    def initialize
        @aliases = {}
        @events  = { :default => [] }
    end

    def do (thing, string)
        stopped = false

        event = Event.new(self, thing, string)

        @events[:default].each {|method|
            result = method.call(event.alias || event.type, event.thing, event.string)

            if result == false
                stopped = true
                break
            elsif result.is_a?(String)
                string = result
            end
        }

        if stopped
            return
        end

        event.callbacks {|callback|
            result = method.call(thing, string)

            if result == false
                break
            elsif result.is_a?(String)
                string = result

                if event.same?(string)
                    dispatch(thing, string)
                    break
                end
            end
        }
    end

    def alias (symbol, regex)
        if !regex
            @aliases.delete(symbol)
        elsif !regex.class == Regexp
            raise 'You have to alias to a Regexp.'
        else
            @aliases[symbol] = regex
        end
    end

    def register (type, callback)
        if @aliases[type]
            type = @aliases[type]
        end

        if !callback
            @events[type].clear
        elsif callback.is_a?(Array)
            callback.each {|callback|
                register(type, callback)
            }
        else
            if !@events[type]
                @events[type] = []
            end

            @events[type].push(callback)
        end
    end
end

end
