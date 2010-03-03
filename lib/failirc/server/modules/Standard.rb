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
require 'failirc/utils'
require 'failirc/server/errors'
require 'failirc/server/responses'

require 'failirc/server/client'
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

                    if user.modes[:registered]
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
            :input => {
                :PING => /^PING( |$)/i,
                :PONG => /^PONG( |$)/i,

                :MODE => /^MODE( |$)/i,

                :PASS => /^PASS( |$)/i,
                :NICK => /^(:[^ ] )?NICK( |$)/i,
                :USER => /^(:[^ ] )?USER( |$)/i,

                :JOIN  => /^(:[^ ] )?JOIN( |$)/i,
                :PART  => /^(:[^ ] )?PART( |$)/i,

                :TOPIC => /^(:[^ ] )?TOPIC( |$)/i,
                :NAMES => /^NAMES( |$)/,

                :PRIVMSG => /^(:[^ ] )?PRIVMSG( |$)/i,

                :QUIT => /^QUIT( |$)/i,
            },
        }

        @events = {
            :pre => self.method(:check),

            :custom => {
                :kill => self.method(:send_quit),

                :user_add    => self.method(:send_join),
                :user_delete => self.method(:send_part),

                :message => self.method(:send_message),

                :topic_change => self.method(:send_topic),
            },

            :default => self.method(:unknown_command),

            :input => {
                :PING => self.method(:ping),
                :PONG => self.method(:pong),

                :MODE => self.method(:mode),

                :PASS => self.method(:auth),
                :NICK => self.method(:nick),
                :USER => self.method(:user),

                :JOIN  => self.method(:join),
                :PART  => self.method(:part),

                :TOPIC => self.method(:topic),
                :NAMES => self.method(:names),

                :PRIVMSG => self.method(:privmsg),

                :QUIT => self.method(:quit),
            },
        }

        super(server)
    end

    def finalize
        Thread.kill(@pingThread)
    end

    def check (event, thing, string)
        if event.chain != :input
            return
        end

        stop = false

        # if the client tries to do something without having registered, kill it with fire
        if event.alias != :PASS && event.alias != :NICK && event.alias != :USER && !thing.modes[:registered]
            thing.send :numeric, ERR_NOTREGISTERED
            stop = true
        # if the client tries to reregister, kill it with fire
        elsif (event.alias == :PASS || event.alias == :NICK || event.alias == :USER) && thing.modes[:registered]
            thing.send :numeric, ERR_ALREADYREGISTRED
            stop = true
        end

        return !stop
    end

    def unknown_command (event, thing, string)
        match = string.match(/^([^ ]+)/)

        if match && thing.modes[:registered]
            thing.send :numeric, ERR_UNKNOWNCOMMAND, match[1]
        end
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

        if !thing.modes[:registered]
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

                thing.host = thing.socket.peeraddr[2]
                thing.ip   = thing.socket.peeraddr[3]
            end

            # try to register it
            registration(thing)
        elsif thing.is_a?(Link)

        end
    end

    def registration (thing)
        if !thing.modes[:registered]
            # if the client isn't registered but has all the needed attributes, register it
            if thing.user && thing.nick
                if thing.listen.attributes['password']
                    if thing.listen.attributes['password'] != thing.password
                        return false
                    end
                end

                thing.modes[:registered] = true

                # clean the temporary hash value and use the nick as key
                thing.server.users.delete(thing.socket)
                thing.server.users[thing.nick] = thing

                @pingedOut.reject! {|user|
                    user == thing
                }

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
                error(thing, "Closing Link: #{thing.nick}[#{thing.ip}] (#{message})")
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

    def mode (thing, string)
        
    end

    def set_mode (user, mode)
        match = mode.match(/^([+\-])(.*)$/)

        if match[1] == '+'
            puts match[2]
            if match[2].match(/o/)
                user.modes[:o]             = true
                user.modes[:can_set_topic] = true

                if !user.modes[:q] && !user.modes[:a]
                    user.modes[:level] = '@'
                end
            end
        else

        end
    end

    def join (thing, string)
        match = string.match(/JOIN\s+(.+)(\s+(.+))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'JOIN'
        else
            channel  = match[1]
            password = match[3]

            if thing.channels[channel]
                return
            end

            if !thing.server.channels[channel]
                thing.server.channels[channel] = Channel.new(server, channel)
            end

            empty = thing.server.channels[channel].empty?
            user  = thing.server.channels[channel].users.add(thing)

            if empty
                set_mode user, '+o'
            end

            thing.channels.add(thing.server.channels[channel])

            if !thing.channels[channel].topic.nil?
                topic thing, "TOPIC #{channel}"
            end

            names thing, "NAMES #{channel}"
        end
    end

    def send_join (thing)
        thing.channel.users.each_value {|user|
            user.send :raw, ":#{thing.mask} JOIN :#{thing.channel.name}"
        }
    end

    def topic (thing, string)
        match = string.match(/TOPIC\s+(.*?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'TOPIC'
        else
            channel = match[1]

            if !thing.channels[channel]
                thing.send :numeric, ERR_NOTONCHANNEL, thing.server.channels[channel]
            else
                if match[2]
                    topic = match[3].to_s

                    if thing.channels[channel].modes[:t] && !thing.channels[channel].user(thing).modes[:can_set_topic]
                        thing.send :numeric, ERR_CHANOPRIVSNEEDED, thing.server.channels[channel]
                    else
                        thing.channels[channel].topic = [thing, topic]
                    end
                else
                    if thing.channels[channel].topic.nil?
                        thing.send :numeric, RPL_NOTOPIC, thing.server.channels[channel]
                    else
                        thing.send :numeric, RPL_TOPIC, thing.server.channels[channel].topic
                        thing.send :numeric, RPL_TOPICSETON, thing.channels[channel].topic
                    end
                end
            end
        end
    end

    def send_topic (channel)
        channel.users.each_value {|user|
            user.send :raw, ":#{channel.topic.setBy.mask} TOPIC #{channel.name} :#{channel.topic}"
        }
    end

    def names (thing, string)
        match = string.match(/NAMES\s+(.*)$/i)

        if !match
            thing.send :numeric, RPL_ENDOFNAMES, thing.nick
        else
            channel = match[1]

            if thing.channels[channel]
                thing.send :numeric, RPL_NAMREPLY, thing.channels[channel]
            end

            thing.send :numeric, RPL_ENDOFNAMES, channel
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
        if thing.client.modes[:quitting]
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

    def privmsg (thing, string)
        match = string.match(/PRIVMSG\s+(.*?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NORECIPIENT, 'PRIVMSG'
        else
            if !match[3]
                thing.send :numeric, ERR_NOTEXTTOSEND
            else
                receiver = match[1]
                text     = match[3]

                if Channel.check(receiver)
                    if thing.channels[receiver]
                        if thing.channels[receiver].modes[:m] && !thing.channels[receiver].user(thing).modes[:can_talk]
                            thing.send :numeric, ERR_CANNOTSENDTOCHAN, receiver
                        else
                            thing.server.dispatcher.execute(:message, thing, thing.channels[receiver], text)
                        end
                    else
                        if !thing.server.channels[receiver]
                            thing.send :numeric, ERR_NOSUCHNICK, receiver
                        else
                            if thing.server.channels[receiver].modes[:n]
                                thing.send :numeric, ERR_CANNOTSENDTOCHAN, receiver
                            else
                                thing.server.dispatcher.execute(:message, thing, thing.server.channels[receiver], text)
                            end
                        end
                    end
                else
                    if !thing.server.users[receiver]
                        thing.send :numeric, ERR_NOSUCHNICK, receiver
                    else
                        thing.server.dispatcher.execute(:message, thing, thing.server.users[receiver], text)
                    end
                end
            end
        end
    end

    def send_message (from, to, text)
        if to.is_a?(Channel)
            to.users.each_value {|user|
                if user.mask != from.mask
                    user.send :raw, ":#{from.mask} PRIVMSG #{to.name} :#{text}"
                end
            }
        elsif to.is_a?(Client) || to.is_a?(User)
            to.send :raw, ":#{from.mask} PRIVMSG #{to.nick} :#{text}"
        end
    end
end

end

end
