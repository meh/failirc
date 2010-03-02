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

require 'resolv'

require 'failirc/server/module'
require 'failirc/utils'
require 'failirc/server/errors'
require 'failirc/server/responses'

require 'failirc/server/channel'
require 'failirc/server/user'

module IRC

module Modules

class Standard < Module
    include Utils

    def initialize (server)
        @pingedOut = []

        @pingThread = Thread.new {
            sleep server.config.elements['config/server/pingTimeout'].text.to_i

            while true
                server.users.each_value {|user|
                    @pingedOut.push(user)

                    if user.registered?
                        user.send :raw, "PING :#{server.host}"
                    end
                }

                sleep server.config.elements['config/server/pingTimeout'].text.to_i

                @pingedOut.each {|user|
                    error(user, 'Ping timeout', :close)
                    server.kill(user, 'Ping timeout')
                }

                @pingedOut.clear
            end
        }

        @aliases = {
            :PING => /^PING( |$)/i,
            :PONG => /^PONG( |$)/i,

            :PASS => /^PASS( |$)/i,
            :NICK => /^(:[^ ] )?NICK( |$)/i,
            :USER => /^(:[^ ] )?USER( |$)/i,

            :JOIN  => /^(:[^ ] )?JOIN( |$)/i,
            :PART  => /^(:[^ ] )?PART( |$)/i,

            :TOPIC => /^(:[^ ] )?TOPIC( |$)/i,
            :NAMES => /^NAMES( |$)/,

            :QUIT => /^QUIT( |$)/i,
        }

        @events = {
            :default => self.method(:check),
            :kill    => self.method(:send_quit),

            :user_add    => self.method(:send_join),
            :user_delete => self.method(:send_part),

            :PING => self.method(:ping),
            :PONG => self.method(:pong),

            :PASS => self.method(:auth),
            :NICK => self.method(:nick),
            :USER => self.method(:user),

            :JOIN  => self.method(:join),
            :PART  => self.method(:part),

            :TOPIC => self.method(:topic),
            :NAMES => self.method(:names),

            :QUIT => self.method(:quit),
        }

        super(server)
    end

    def finalize
        Thread.kill(@pingThread)
    end

    def check (type, thing, string)
        stop = false

        # if the client tries to do something without having registered, kill it with fire
        if type != :PASS && type != :NICK && type != :USER && !thing.registered?
            thing.send :numeric, ERR_NOTREGISTERED
            stop = true
        # if the client tries to reregister, kill it with fire
        elsif (type == :PASS || type == :NICK || type == :USER) && thing.registered?
            thing.send :numeric, ERR_ALREADYREGISTRED
            stop = true
        end

        return !stop
    end

    def auth (thing, string)
        match = string.match(/PASS\s+(.+)$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'PASS'
        else
            thing.password = match[1]

            # try to register it
            registration(thing)
        end
    end

    def nick (thing, string)
        if !thing.is_a?(Client)
            return
        end

        match = string.match(/NICK\s+(.+)$/i)

        # no nickname was passed, so tell the user is a faggot
        if !match
            thing.send :numeric, ERR_NONICKNAMEGIVEN
            return
        end
        
        # check if the nickname is valid
        if !match[1].match(/[\w\-^\/]{1,23}/)
            thing.send :numeric, ERR_ERRONEUSNICKNAME, match[1]
            return
        end

        if !thing.registered?
            # if the user hasn't registered yet and the choosen nick is already used,
            # kill it with fire.
            if thing.server.users[match[1]]
                thing.send :numeric, ERR_NICKCOLLISION, match[1]
                error(thing, 'Nick collision', :close)
                thing.server.kill(thing)
            else
                thing.nick = match[1]

                # try to register it
                registration(thing)
            end
        else
            # if the user has already registered and the choosen nick is already used,
            # just tell him that he's a faggot.
            if thing.server.users[match[1]]
                thing.send :numeric, ERR_NICKNAMEINUSE, match[1]
            else
                mask       = thing.mask
                thing.nick = match[1]

                thing.channels.users.each_key {|user|
                    user.send :raw, "#{mask} NICK :#{user}"
                }
            end
        end

    end

    def user (thing, string)
        if thing.is_a?(Client)
            match = string.match(/USER\s+([^ ]+)\s+[^ ]+\s+[^ ]+\s+:(.+)$/i)

            if !match
                thing.send :numeric, ERR_NEEDMOREPARAMS, 'USER'
            else
                thing.user     = match[1]
                thing.realName = match[2]

                thing.host = Resolv.getname(thing.socket.addr.pop)
            end

            # try to register it
            registration(thing)
        elsif thing.is_a?(Link)

        end
    end

    def registration (thing)
        if !thing.registered?
            # if the client isn't registered but has all the needed attributes, register it
            if thing.user && thing.nick
                if thing.listen.attributes['password']
                    if thing.listen.attributes['password'] != thing.password
                        return false
                    end
                end

                thing.registered = true

                # clean the temporary hash value and use the nick as key
                thing.server.users.delete(thing.socket)
                thing.server.users[thing.nick] = thing

                thing.server.dispatcher.execute(:registration, thing)

                thing.send :numeric, RPL_WELCOME, thing
                thing.send :numeric, RPL_HOSTEDBY, thing
                thing.send :numeric, RPL_SERVCREATEDON

                send_motd(thing)
            end
        end
    end

    def error (thing, message, type=nil)
        case type
            when :close
                error(thing, "Closing Link: #{thing.nick}[#{thing.socket.addr.pop}] (#{message})")
            else
                thing.send :raw, "ERROR :#{message}"
        end
    end

    def send_motd (user)
        user.send :numeric, RPL_MOTDSTART

        offset = 0
        motd   = user.server.config.elements['config/server/motd'].text.strip

        while line = motd[offset, 80]
            user.send :numeric, RPL_MOTD, line
            offset += 80
        end

        user.send :numeric, RPL_ENDOFMOTD
    end

    def ping (thing, string)
        match = string.match(/PING\s+(.*)$/i)

        if !match
            thing.send :numeric, ERR_NOORIGIN
        else
            if match[1] == thing.server.host
                thing.send :raw, ":#{thing.server.host} PONG #{thing.server.host} :#{thing.server.host}"
            else
                thing.send :numeric, ERR_NOSUCHSERVER, match[1]
            end
        end
    end

    def pong (thing, string)
        match = string.match(/PONG\s+(:)?(.*)$/i)

        if !match
            thing.send :numeric, ERR_NOORIGIN
        else
            if match[2] == thing.server.host
                @pingedOut.reject! {|user|
                    user == thing
                }
            else
                thing.send :numeric, ERR_NOSUCHSERVER, match[2]
            end
        end
    end

    def join (thing, string)
        match = string.match(/JOIN\s+(.+)(\s+(.+))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'JOIN'
        else
            channel  = match[1]
            password = match[3]

            if !thing.server.channels[channel]
                thing.server.channels[channel] = Channel.new(channel)
            end

            user = thing.server.channels[channel].users.add(thing)

            if thing.server.channels[channel].empty?
                user.modes[:o] = true
            end

            thing.channels.add(thing.server.channels[channel])

            if !thing.channels[channel].topic.nil?
                thing.server.dispatcher.execute(@aliases[:TOPIC], thing, "TOPIC #{channel}")
            end
        end
    end

    def send_join (thing)
        thing.channel.users.each_value {|user|
            user.send :raw, ":#{thing.mask} JOIN :#{thing.channel.name}"
        }
    end

    def topic (thing, string)
        match = string.match(/TOPIC\s+(.*)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'TOPIC'
        else
            if !thing.channels[match[1]]
                thing.send :numeric, ERR_NOTONCHANNEL, thing.server.channels[match[1]]
            else
                if match[2]
                    if thing.channels[match[1]].modes[:t]
                        thing.send :numeric, ERR_CHANOPRIVSNEEDED, thing.server.channels[match[1]]
                    else
                        thing.channels[match[1]].topic = match[2].to_s
                    end
                else
                    if thing.channels[match[1]].topic.nil?
                        thing.send :numeric, RPL_NOTOPIC, thing.server.channels[match[1]]
                    else
                        thing.send :numeric, RPL_TOPIC, thing.server.channels[match[1]]
                    end
                end
            end
        end
    end

    def part (thing, string)
        match = string.match(/PART\s+(.+)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'PART'
        else
            if !thing.server.channels[match[1]]
                thing.send :numeric, ERR_NOSUCHCHANNEL, match[1]
            elsif !thing.channels[match[1]]
                thing.send :numeric, ERR_NOTONCHANNEL, thing.server.channels[match[1]]
            else
                thing.server.channels[match[1]].users.delete(thing, match[2])
                thing.channels.delete(match[1])
            end
        end
    end

    def send_part (thing, message)
        if thing.quitting?
            return
        end

        thing.channel.users.each_value {|user|
            user.send :raw, ":#{thing.mask} PART #{thing.channel.name} :#{message}"
        }
    end

    def quit (thing, string)
        match = /QUIT(\s+:(.*))?$/i.match(string)

        thing.server.kill(thing, "#{thing.server.config.elements['config/messages/quit'].text}#{match[2] || thing.nick}")
    end

    def send_quit (thing, message)
        thing.channels.users.each_value {|user|
            user.send :raw, ":#{thing.mask} QUIT :#{message}"
        }
    end 
end

end

end
