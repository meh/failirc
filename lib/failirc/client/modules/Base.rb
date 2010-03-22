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
require 'failirc/mask'
require 'failirc/errors'
require 'failirc/responses'

require 'failirc/client/module'

module IRC

class Client

module Modules

class Base < Module
    @@version = '0.0.1'

    def self.version
        @@version
    end

    def description
        "Base-#{Base.version}"
    end

    def initialize (client)
        @aliases = {
            :input => {
                :PING => /^PING( |$)/i,

                :NUMERIC => /^:([^ ]+)\s+(\d{3})\s+(.+)/,

                :JOIN => /^:.+?\s+JOIN\s+:./i,
            },
        }

        @events = {
            :custom => {
                :connect => self.method(:connect),

                :join => self.method(:join),
            },

            :input => {
                :PING => self.method(:pong),

                :NUMERIC => self.method(:numeric),

                :JOIN => self.method(:joined),
            },
        }

        super(client)
    end

    def connect (server)
        if server.password
            server.send :raw, "PASS #{server.password}"
        end

        server.send :raw, "NICK #{client.nick}"
        server.send :raw, "USER #{client.user} * * :#{client.realName}"
    end

    def pong (server, string)
        match = string.match(/PING\s+(.*)$/)

        if match
            server.send :raw, "PONG #{match[1]}"
        end
    end

    def numeric (server, string)
        match = string.match(/^:[^ ]+\s+(\d{3})\s+.+?(\s+(.*))?$/)

        if match
            client.dispatcher.execute :numeric, server, match[1].to_i, match[3]
        end
    end

    def join (server, channel)
        server.send :raw, "JOIN #{channel}"
    end

    def joined (server, string)
        match = string.match(/^:(.+?)\s+JOIN\s+:(.+)$/i)

        if match
            mask    = Mask.parse(match[1])
            channel = match[2]

            if mask.nick == server.nick
                server.channels[channel] = Channel.new(server, channel)
            end
        end
    end
end

end

end

end
