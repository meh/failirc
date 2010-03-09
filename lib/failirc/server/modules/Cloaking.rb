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

require 'failirc/server/module'

module IRC

module Modules

class Cloaking < Module
    def initialize (server)
        @aliases = {
            :output => {
                :NAMES => /:.*? 353 /,
            }
        }

        @events = {
            :output => {
                :NAMES => Event::Callback.new(self.method(:hide), -9001),
            }
        }

        super(server)
    end

    def hide (thing, string)
        match = string.match(/:.*? (\d+)/)

        if !match
            return
        end

        self.method("_#{match[1]}".to_sym).call(string) rescue nil
    end

    def _353 (string)
        match = string.match(/353 .*?:(.*)$/)

        names = match[1].split(/\s+/)
        list  = ''

        names.each {|original|
            if original.match(/^[+%@&@]/)
                name = original[1, original.length]
            else
                name = original
            end

            if !server.clients[name]
                next
            end

            client = server.clients[name]

            if !(client.modes[:operator] && client.modes[:extended][:hide])
                list << " #{original}"
            end
        }

        string.sub!(/ :(.*)$/, " :#{list[1, list.length]}")
    end
end

end

end
