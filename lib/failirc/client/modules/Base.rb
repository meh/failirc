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

    @@supported = {}

    def self.version
        @@version
    end

    def self.supported
        @@supported
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

                :quit => self.method(:do_quit),
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
        module Server
            @@defaultSupportedModes = [
                { :mode => 'o', :status => '@' },
                { :mode => 'h', :status => '%' },
                { :mode => 'v', :status => '+' }
            ]

            def self.supportedModes
                if !Base.supported['PREFIX']
                    return @@defaultSupportedModes
                else
                    match = Base.supported['PREFIX'].match(/\((.*?)\)(.*)$/)

                    if !match
                        return @@defaultSupportedModes
                    else
                        modes    = match[1].split
                        statuses = match[2].split
                        result   = []

                        1.upto(modes.length) {|f|
                            result.push({
                                :mode   => modes.shift
                                :status => statuses.shift
                            })
                        }

                        return result
                    end
                end
            end
        end

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

        # stuff supported by the server
        when 5
            message.split(/\s+/).each {|support|
                support = support.split(/=/)

                Base.supported[support[0]] = support[1]
            }

        # end of MOTD or no MOTD, hence concluded connection.
        when 376, 422
            client.dispatcher.execute :connected, server

        # WHO reply
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

    def join (server, channel, password=nil)
        text = "JOIN #{channel}"

        if password
            text << " #{password}"
        end

        server.send :raw, text
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

        if match = message.match(/^\x01([^ ]*)( (.*?))?\x01$/)
            client.execute :ctcp, server, :message, from, to, match[1], match[3]
        else
            client.execute :message, server, :input, from, to, message
        end
    end

    def send_message (server, chain, from, to, message)
        if chain != :output
            return
        end

        if to.is_a?(Channel)
            name = to.name
        elsif to.is_a?(Client)
            name = to.nick
        end

        server.send :raw, "PRIVMSG #{name} :#{message}"
    end

    def notice (server, string)
        match = string.match(/:(.+?)\s+NOTICE\s+(.+)\s+:(.*)$/i)

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

        if match = message.match(/^\x01([^ ]*)( (.*?))?\x01$/)
            client.execute :ctcp, server, :notice, from, to, match[1], match[3]
        else
            client.execute :message, server, :input, from, to, message
        end
    end


    def send_notice (server, chain, from, to, message, level=nil)
        if chain != :output
            return
        end

        if to.is_a?(Channel)
            name = "#{level}#{to.name}"
        elsif to.is_a?(Client)
            name = to.nick
        end

        server.send :raw, "NOTICE #{name} :#{message}"
    end

    def send_ctcp (server, kind, chain, from, to, type, message, level=nil)

    end

    def do_quit (server, message)
        if message
            server.send :raw, "QUIT #{message}"
        else
            server.send :raw, "QUIT"
        end
    end
end

end

end

end
