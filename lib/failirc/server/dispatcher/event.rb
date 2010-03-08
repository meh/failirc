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

module IRC

class Event
    class Callback
        attr_reader :method
        attr_accessor :priority

        def initialize (method, priority=0)
            @method   = method
            @priority = priority
        end

        def call (*args)
            return @method.call(*args)
        end
    end

    attr_reader :type, :chain, :alias, :dispatcher, :thing, :string
    attr_accessor :special

    def initialize (dispatcher, chain, thing, string)
        @dispatcher = dispatcher
        @chain      = chain
        @thing      = thing
        @string     = string
        @type       = Event.type(dispatcher, chain, string)
        @alias      = Event.alias(dispatcher, chain, type)
        @callbacks  = Event.callbacks(dispatcher, chain, type)
    end

    def callbacks
        if @callbacks
            return @callbacks
        else
            tmp = Event.callbacks(@dispatcher, @chain, @type)

            if tmp
                return @callbacks = tmp
            else
                return []
            end
        end
    end

    def same? (string)
        if @type.class != Regexp
            raise '@type is not a Regexp.'
        end

        return (@type.match(string)) ? true : false
    end

    def self.type (dispatcher, chain, string)
        dispatcher.events[chain].each_key {|key|
            if key.class == Regexp && key.match(string)
                return key
            end
        }

        return nil
    end

    def self.alias (dispatcher, chain, type)
        dispatcher.aliases[chain].each {|key, value|
            if type == value
                return key
            end
        }

        return nil
    end

    def self.callbacks (dispatcher, chain, type)
        if chain == :pre || chain == :post || chain == :default
            return dispatcher.events[chain]
        else
            return dispatcher.events[chain][type]
        end
    end
end

end
