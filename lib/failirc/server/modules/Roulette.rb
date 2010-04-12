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

require 'failirc/module'

module IRC

class Server

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
        if tmp = @server.config.elements['config/modules/module[@name="Roulette"]/death']
            @death = tmp.text
        else
            @death = 'BOOM, dickshot'
        end

        if tmp = @server.config.elements['config/modules/module[@name="Roulette"]/life']
            @life = tmp.text
        else
            @life = '#{user.nick} shot but survived :('
        end
    end

    def roulette (thing, string)
        user = thing

        if rand(3) == 1
            @server.kill thing, eval(@death.inspect.gsub(/\\#/, '#'))
        else
            @server.clients.each_value {|client|
                if client.modes[:registered]
                    @server.dispatcher.execute :notice, @server, client, eval(@life.inspect.gsub(/\\#/, '#'))
                end
            }
        end
    end
end

end

end

end
