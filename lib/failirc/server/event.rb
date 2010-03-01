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
    attr_reader :type, :dispatcher, :thing, :string

    def initialize (dispatcher, thing, string)
        @dispatcher = dispatcher
        @thing      = thing
        @string     = string
        @type       = Event.type(dispatcher, string)
    end

    def callbacks
        if @dispatcher.events[@type]
            return @dispatcher.events[@type]
        else
            return []
        end
    end

    def same? (string)
        return (@type.match(string)) ? true : false
    end

    def self.type (dispatcher, string)
        type = nil

        dispatcher.events.each_key {|key|
            if key.match(string)
                type = key
                break
            end
        }

        return type
    end


    end
end

end
