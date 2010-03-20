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

module IRC

class Server

class Dispatcher

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

    attr_reader :types, :chain, :aliases, :dispatcher, :thing, :string
    attr_accessor :special

    def initialize (dispatcher, chain, thing, string)
        @dispatcher = dispatcher
        @chain      = chain
        @thing      = thing
        @string     = string
        @types      = Event.types(dispatcher, chain, string)
        @aliases    = Event.aliases(dispatcher, chain, types)
        @callbacks  = Event.callbacks(dispatcher, chain, types)
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

    def self.types (dispatcher, chain, string)
        types = []

        dispatcher.events[chain].each_key {|key|
            if key.class == Regexp && key.match(string)
                types.push key
            end
        }

        return types
    end

    def self.aliases (dispatcher, chain, types)
        aliases = []

        dispatcher.aliases[chain].each {|key, value|
            if types.include?(value)
                aliases.push key
            end
        }

        return aliases
    end

    def self.callbacks (dispatcher, chain, types)
        callbacks = []

        if chain == :pre || chain == :post || chain == :default
            callbacks.insert(-1, *dispatcher.events[chain])
        else
            types.each {|type|
                callbacks.insert(-1, *dispatcher.events[chain][type])
            }
        end

        return callbacks
    end
end

end

Event = Dispatcher::Event

end

end
