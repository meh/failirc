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

require 'failirc/client/channel'
require 'failirc/client/user'
require 'failirc/client/client'

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
                :NUMERIC => /^:([^ ]+)\s+(\d{3})\s+(.+)/,

                :PING => /^PING( |$)/i,

                :JOIN => /^:.+?\s+JOIN\s+:./i,

                :PRIVMSG => /^:.+?\s+PRIVMSG\s+.+?\s+:/i,
            },
        }

        @events = {
            :custom => {
                :connect => self.method(:connect),
                :numeric => self.method(:received_numeric),

                :join => self.method(:join),
                :who  => self.method(:who),

                :message => self.method(:send_message),
            },

            :input => {
                :NUMERIC => self.method(:numeric),

                :PING => self.method(:pong),

                :JOIN => self.method(:joined),

                :PRIVMSG => self.method(:message),
            },
        }

        super(client)
    end

    module Utils
        module Channel
            def self.isValid (string)
                string.match(/^[&#+!][^ ,:\a]{0,50}$/) ? true : false
            end
        end
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

    def received_numeric (server, number, message)
        case number

        when 352
            match = message.match(/(.+?)\s+(.+?)\s+(.+?)\s+.+?\s+(.+?)\s+.+?\s+:\d+\s+(.+)$/)

            if !match
                return
            end

            channel  = match[1]
            mask     = Mask.new(match[4], match[2], match[3])
            realName = match[5]

            if !server.channels[channel]
                server.channels[channel] = Channel.new(server, channel)
            end

            channel = server.channels[channel]

            if mask.nick == server.nick
                return
            end

            if !server.clients[mask.nick] || server.clients[mask.nick].mask != mask
                server.clients[mask.nick]          = Client.new(server, mask)
                server.clients[mask.nick].realName = realName
            end

            channel.add(server.clients[mask.nick])

        end
    end

    def join (server, channel)
        server.send :raw, "JOIN #{channel}"
        client.execute :who, server, channel
    end

    def joined (server, string)
        match = string.match(/^:(.+?)\s+JOIN\s+:(.+)$/i)

        if !match
            return
        end

        mask    = Mask.parse(match[1])
        channel = match[2]

        if mask.nick == server.nick
            if !server.channels[channel]
                server.channels[channel] = Channel.new(server, channel)
            end
        else
            if !server.clients[mask.nick] || server.clients[mask.nick].mask != mask
                server.clients[mask.nick] = Client.new(server, mask)
            end

            if server.channels[channel]
                server.channels[channel].add(server.clients[mask.nick])
            end
        end
    end

    def who (server, channel)
        server.send :raw, "WHO #{channel}"
    end

    def message (server, string)
        match = string.match(/:(.+?)\s+PRIVMSG\s+(.+)\s+:(.*)$/i)

        if !match
            return
        end

        from = Mask.parse(match[1])

        if !server.clients[from.nick] || server.clients[from.nick] != from
            from = server.clients[from.nick] = Client.new(server, from)
        else
            from = server.clients[from.nick]
        end

        to = match[2]

        if Utils::Channel::isValid(to)
            to   = server.channels[to]
            from = to.user from
        else
            to = client
        end

        message = match[3]

        client.execute :message, server, :input, from, to, message
    end

    def send_message (server, chain, from, to, message)
        if chain != :output
            return
        end

        if to.is_a?(Channel)
            server.send :raw, "PRIVMSG #{to.name} :#{message}"
        elsif to.is_a?(Client)
            server.send :raw, "PRIVMSG #{to.nick} :#{message}"
        end
    end
end

end

end

end
