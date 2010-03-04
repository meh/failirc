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

class Roulette < Module
    def initialize (server)
        @aliases = {
            :input => {
                :ROULETTE => /^ROULETTE( |$)/i,
            },
        }

        @events = {
            :input => {
                :ROULETTE => self.method(:roulette),
            },
        }

        super(server)
    end

    def rehash
        @death = @server.config.elements['config/modules/module[@name="Roulette"]/death']

        if @death
            @death = @death.text
        else
            @death = 'BOOM, dickshot'
        end

        @life = @server.config.elements['config/modules/module[@name="Roulette"]/life']

        if @life
            @life = @life.text
        else
            @life = 'The faggot shot but survived :('
        end
    end

    def roulette (thing, string)
        if rand(3) == 1
            @server.kill(thing, @death)
        else
            @server.clients.each_value {|client|
                if client.modes[:registered]
                    @server.modules['Standard'].send_notice(thing, client, @life)
                end
            }
        end
    end
end

end

end
