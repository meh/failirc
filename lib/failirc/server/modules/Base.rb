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

require 'failirc/extensions'

require 'failirc/server/module'
require 'failirc/server/errors'
require 'failirc/server/responses'

require 'failirc/server/client'
require 'failirc/server/channel'
require 'failirc/server/user'

module IRC

module Modules

class Base < Module
    def initialize (server)
        @pingedOut = ThreadSafeHash.new
        @toPing    = ThreadSafeHash.new

        @pingThread = Thread.new {
            while true
                @toPing.each_value {|client|
                    @pingedOut[client.socket] = client

                    if client.modes[:registered]
                        client.send :raw, "PING :#{server.host}"
                    end
                }

                @toPing.clear
                @toPing.merge!(::Hash[server.clients.values.collect {|client| [client.socket, client]}])

                sleep server.config.elements['config/server/pingTimeout'].text.to_i

                @pingedOut.each_value {|client|
                    if !client.socket.closed?
                        Utils::error(client, 'Ping timeout', :close)
                        server.kill(client, 'Ping timeout')
                    end
                }

                @pingedOut.clear
            end
        }

        @aliases = {
            :input => {
                :PING => /^PING( |$)/i,
                :PONG => /^PONG( |$)/i,

                :MODE => /^MODE( |$)/i,
                :OPER => /^OPER( |$)/i,

                :PASS => /^PASS( |$)/i,
                :NICK => /^(:[^ ] )?NICK( |$)/i,
                :USER => /^(:[^ ] )?USER( |$)/i,

                :JOIN => /^(:[^ ] )?JOIN( |$)/i,
                :PART => /^(:[^ ] )?PART( |$)/i,
                :KICK => /^(:[^ ] )?KICK( |$)/i,

                :TOPIC => /^(:[^ ] )?TOPIC( |$)/i,
                :NAMES => /^NAMES( |$)/i,
                :WHO   => /^WHO( |$)/i,

                :PRIVMSG => /^(:[^ ] )?PRIVMSG( |$)/i,
                :NOTICE  => /^NOTICE( |$)/i,

                :MAP     => /^MAP( |$)/i,
                :VERSION => /^VERSION( |$)/i,

                :QUIT => /^QUIT( |$)/i,
            },
        }

        @events = {
            :pre => self.method(:check),

            :custom => {
                :kill => self.method(:send_quit),

                :join => self.method(:send_join),
                :part => self.method(:send_part),
                :kick => self.method(:send_kick),

                :message => self.method(:send_message),
                :notice  => self.method(:send_notice),

                :topic_change => self.method(:send_topic),
            },

            :default => self.method(:unknown_command),

            :input => {
                :PING => self.method(:ping),
                :PONG => self.method(:pong),

                :MODE => self.method(:mode),
                :OPER => self.method(:oper),

                :PASS => self.method(:pass),
                :NICK => self.method(:nick),
                :USER => self.method(:user),

                :JOIN => self.method(:join),
                :PART => self.method(:part),
                :KICK => self.method(:kick),

                :TOPIC => self.method(:topic),
                :NAMES => self.method(:names),
                :WHO   => self.method(:who),

                :PRIVMSG => self.method(:privmsg),
                :NOTICE  => self.method(:notice),

                :MAP     => self.method(:map),
                :VERSION => self.method(:version),

                :QUIT => self.method(:quit),
            },
        }

        super(server)
    end

    def rehash
        @messages = {}

        if tmp = server.config.elements['config/modules/modules[@name="Base"]/messages/quit']
            @messages[:quit] = tmp.text
        else
            @messages[:quit] = 'Quit: #{message}'
        end
    end

    def finalize
        Thread.kill(@pingThread)
    end

    module Utils
        include IRC::Utils

        module Client
            class Action
                attr_reader :client, :event, :string, :on

                def initialize (client, event, string)
                    @client = client
                    @event  = event
                    @string = string
                    @on     = Time.now
                end
            end
        end

        module Channel
            class Ban
                attr_reader :setBy, :setOn, :channel, :mask

                def initialize (by, channel, mask)
                    @setBy   = by
                    @setOn   = Time.now
                    @channel = channel
                    @mask    = mask
                end

                def to_s
                    "#{channel} #{mask} #{setBy.nick} #{setOn.tv_sec}"
                end
            end

            class Invitation
                attr_reader :setBy, :setOn, :channel, :mask

                def initialize (by, channel, mask)
                    @setBy   = by
                    @setOn   = Time.now
                    @channel = channel
                    @mask    = mask
                end

                def to_s
                    "#{channel} #{mask} #{setBy.nick} #{setOn.tv_sec}"
                end
            end

            def self.isValid (string)
                string.match(/^[&#+!][^ ,:\a]{0,50}$/) ? true : false
            end
    
            def self.invited? (channel, client)
                if !channel.modes[:i]
                    return true
                end

                channel.modes[:invites].each {|invite|
                    if invite.mask.match(client.mask)
                        return true
                    end
                }

                return false
            end

            def self.banned? (channel, client)
                channel.modes[:bans].each {|ban|
                    if ban.mask.match(client.mask)
                        return true
                    end
                }

                return false
            end
        end

        @nicks = ThreadSafeHash.new

        def self.registration (thing)
            if !thing.modes[:registered]
                if thing.nick
                    if (@nicks[thing.nick] && @nicks[thing.nick] != thing) || thing.server.clients[thing.nick]
                        thing.send :numeric, ERR_NICKNAMEINUSE, thing.nick
                        return
                    end

                    @nicks[thing.nick] = thing
                end

                # if the client isn't registered but has all the needed attributes, register it
                if thing.user && thing.nick
                    if thing.listen.attributes['password'] && thing.listen.attributes['password'] != thing.password
                        return false
                    end

                    thing.modes[:registered] = true
    
                    # clean the temporary hash value and use the nick as key
                    thing.server.clients.delete(thing.socket)
                    thing.server.clients[thing.nick] = thing

                    @nicks.delete(thing.nick)
    
                    thing.server.dispatcher.execute(:registration, thing)
    
                    thing.send :numeric, RPL_WELCOME, thing
                    thing.send :numeric, RPL_HOSTEDBY, thing
                    thing.send :numeric, RPL_SERVCREATEDON
    
                    motd(thing)
                end
            end
        end

        def self.error (thing, message, type=nil)
            case type
                when :close
                    error(thing, "Closing Link: #{thing.nick}[#{thing.ip}] (#{message})")
                else
                    thing.send :raw, "ERROR :#{message}"
            end
        end

        def self.motd (user)
            user.send :numeric, RPL_MOTDSTART
    
            offset = 0
            motd   = user.server.config.elements['config/server/motd'].text.strip
    
            while line = motd[offset, 80]
                user.send :numeric, RPL_MOTD, line
                offset += 80
            end
    
            user.send :numeric, RPL_ENDOFMOTD
        end

        @@modes = {
            :channel => {
                :a => :anonymous,
                :i => :inviteOnly,
                :m => :moderated,
                :n => :no_external_messages,
                :s => :secret,
                :t => :topic_change_needs_privileges,
                :z => :ssl_only,
            },

            :user => {
                :can_change_channel_modes => [:can_change_channel_extended_modes, :can_change_topic_mode, :can_change_no_external_messages_mode],

                :a => [:o, :admin],
                :o => [:h, :operator, :can_kick, :can_change_topic, :can_give_channel_operator, :can_change_channel_modes, :can_change_user_modes],
                :h => [:v, :halfoperator, :can_kick],
                :v => [:voice, :can_talk],
            },

            :client => {
                :o => [:operator, :can_kick, :can_change_topic, :can_give_channel_operator],
            },
        }

        def self.setFlags (thing, type, value)
            if thing.is_a?(IRC::Channel)
                main = @@modes[:channel]
            elsif thing.is_a?(IRC::User)
                main = @@modes[:user]
            elsif thing.is_a?(IRC::Client)
                main = @@modes[:client]
            else
                raise 'I don\'t know what to do'
            end

            modes             = main[type]
            thing.modes[type] = value

            if modes.is_a?(Array)
                modes.each {|mode|
                    if main.has_key?(mode) && !thing.modes.has_key?(mode)
                        self.setFlags(thing, mode, value)
                    else
                        thing.modes[mode] = value
                    end
                }
            else
                thing.modes[modes] = value
            end
        end

        def self.setMode (from, thing, request, noAnswer=false)
            if match = request.match(/^=(.*)$/)
                value = match[1].strip

                if value == '?'
                    if thing.is_a?(IRC::Channel)
                        name = thing.name
                    elsif thing.is_a?(IRC::User)
                        name = "#{thing.nick}@#{thing.channel.name}"
                    elsif thing.is_a?(IRC::Client)
                        name = thing.nick
                    end

                    thing.modes[:extended].each {|key, value|
                        from.server.dispatcher.execute :notice, from.server, from, "#{name} #{key} = #{value}"
                    }

                    return
                end

                if thing.is_a?(IRC::Channel) && !from.modes[:can_change_channel_extended_modes]
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                    return
                elsif thing.is_a?(IRC::User) && !from.modes[:can_change_user_extended_modes]
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.channel.name
                    return
                elsif thing.is_a?(IRC::Client) && from.nick != thing.nick && !from.modes[:can_change_client_extended_modes]
                    from.send :numeric, ERR_NOPRIVILEGES
                    return
                end

                modes = value.split(/,/)

                modes.each {|mode|
                    if mode[0, 1] == '-'
                        type = '-'
                    else
                        type = '+'
                    end

                    if mode.match(/^[+\-]/)
                        mode = mode[1, mode.length]
                    end

                    mode = mode.split(/=/)

                    if type == '+'
                        thing.modes[:extended][mode[0].to_sym] = mode[1] || true
                    else
                        thing.modes[:extended].delete(mode[0].to_sym)
                    end
                }
            else
                match = request.match(/^\s*([+\-])?\s*([^ ]+)(\s+(.+))?$/)

                if !match
                    return false
                end

                outputModes  = []
                outputValues = []

                type   = match[1] || '+'
                modes  = match[2].split(//)
                values = (match[4] || '').split(/ /)

                modes.each {|mode|
                    if thing.is_a?(IRC::Channel)
                        case mode

                        when 'b'
                            if type == '+'
                                if values.empty?
                                    thing.modes[:bans].each {|ban|
                                        from.send :numeric, RPL_BANLIST, ban
                                    }

                                    from.send :numeric, RPL_ENDOFBANLIST, thing.name
                                else
                                end
                            end

                        when 'n'
                            if from.is_a?(Server) || from.modes[:can_change_no_external_messages_mode]

                            end

                        when 'o'
                            if from.is_a?(Server) || from.modes[:can_give_channel_operator]
                                value = values.shift

                                if !(user = thing.users[value])
                                    from.send :numeric, ERR_NOSUCHNICK, value
                                    next
                                end

                                if type == '+'
                                    self.setFlags(user, :o, true)

                                    if !user.modes[:q] && !user.modes[:a]
                                        user.modes[:level] = '@'
                                    end
                                else
                                    self.setFlags(user, :o, false)
                                end

                                outputModes.push('o')
                                outputValues.push(value)
                            else
                                from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                            end

                        when 't'
                            if from.modes[:can_change_topic_mode]
                                self.setFlags(thing, :t, type == '+')

                                outputModes.push('t')
                            else
                                from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                            end
                        end
                    elsif thing.is_a?(IRC::Client)
                    end

                    if from.is_a?(User)
                        from = from.client
                    end

                    if !noAnswer && (!outputModes.empty? || !outputValues.empty?)
                        thing.send :raw, ":#{from} MODE #{thing.is_a?(IRC::Channel) ? thing.name : thing.nick} #{type}#{outputModes.join('')} #{outputValues.join(' ')}"
                    end
                }
            end
        end
    end

    def check (event, thing, string)
        if event.chain != :input || !thing || !string
            return
        end

        @toPing.delete(thing.socket)
        @pingedOut.delete(thing.socket)

        thing.modes[:last_action] = Utils::Client::Action.new(thing, event, string)

        stop = false

        # if the client tries to do something without having registered, kill it with fire
        if event.alias != :PASS && event.alias != :NICK && event.alias != :USER && !thing.modes[:registered]
            thing.send :numeric, ERR_NOTREGISTERED
            stop = true
        # if the client tries to reregister, kill it with fire
        elsif (event.alias == :PASS || event.alias == :USER) && thing.modes[:registered]
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

    def ping (thing, string)
        match = string.match(/PING\s+(.*)$/i)

        if !match
            thing.send :numeric, ERR_NOORIGIN
            return
        end

        thing.send :raw, ":#{thing.server.host} PONG #{thing.server.host} :#{match[1]}"

        # RFC isn't that clear about when this error should be shoot
        # thing.send :numeric, ERR_NOSUCHSERVER, match[1]
    end

    def pong (thing, string)
        match = string.match(/PONG\s+(:)?(.*)$/i)

        if !match
            thing.send :numeric, ERR_NOORIGIN
            return
        end

        if match[2] == thing.server.host
            @pingedOut.delete(thing.socket)
        else
            thing.send :numeric, ERR_NOSUCHSERVER, match[2]
        end
    end

    def mode (thing, string)
        # MODE user/channel = +option,-option
        match = string.match(/MODE\s+([^ ]+)(\s+(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'MODE'
            return
        end

        name  = match[1]
        value = match[3] || ''

        # long options, extended protocol
        if match = value.match(/^=\s+(.*)$/)
            if Utils::Channel::isValid(name)
                channel = thing.server.channels[name]

                if channel
                    Utils::setMode(channel.user(thing) || thing, channel, value)
                else
                    thing.send :numeric, ERR_NOSUCHCHANNEL, name
                end
            elsif match = name.match(/^([^@])@(.*)$/)
                user    = match[1]
                channel = match[2]

                if tmp = thing.server.channels[channel]
                    channel = tmp

                    if tmp = thing.server.clients[user]
                        if tmp = channel.user(tmp)
                            user = tmp

                            Utils::setMode(thing, user, value)
                        else
                            thing.send :numeric, ERR_USERNOTINCHANNEL, {
                                :nick    => user,
                                :channel => channel,
                            }
                        end
                    else
                        thing.send :numeric, ERR_NOSUCHNICK, user
                    end
                else
                    thing.send :numeric, ERR_NOSUCHCHANNEL, channel
                end
            else
                if tmp = thing.server.clients[name]
                    client = tmp

                    Utils::setMode(thing, client, value)
                else
                    thing.send :numeric, ERR_NOSUCHNICK, name
                end
            end
        # usual shit
        else
            if Utils::Channel::isValid(name)
                if thing.server.channels[name]
                    channel = thing.server.channels[name]

                    if value.empty?
                        thing.send :numeric, RPL_CHANNELMODEIS, channel
                        thing.send :numeric, RPL_CHANCREATEDON, channel
                    else
                        if thing.channels[name]
                            thing = thing.channels[name].user(thing)
                        end

                        Utils::setMode thing, channel, value
                    end
                else
                    thing.send :numeric, ERR_NOSUCHCHANNEL, name
                end
            else
                if thing.server.clients[name]
                    Utils::setMode(thing, thing.server.clients[name], value)
                else
                    thing.send :numeric, ERR_NOSUCHNICK, name
                end
            end
        end
    end

    def oper (thing, string)
        match = string.match(/OPER\s+(.*?)\s+(.*?)$/)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'OPER'
            return
        end

        server.config.elements['operators/operator'].each {|element|
            thing.send :numeric, RPL_YOUREOPER
        }

        thing.send :numeric, ERR_NOOPERHOST
    end

    def pass (thing, string)
        match = string.match(/PASS\s+(.+)$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'PASS'
        else
            thing.password = match[1]

            if thing.listen.attributes['password']
                if thing.password != thing.listen.attributes['password']
                    error(thing, :close, 'Password mismatch')
                    server.kill thing, 'Password mismatch'
                    return
                end
            end

            # try to register it
            Utils::registration(thing)
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

        nick = match[1]

        thing.server.dispatcher.execute(:user_nick_change, thing, nick)

        # check if the nickname is valid
        if !nick.match(/^[\w\-^\/]{1,23}$/)
            thing.send :numeric, ERR_ERRONEUSNICKNAME, nick
            return
        end

        if !thing.modes[:registered]
            # if the user hasn't registered yet and the choosen nick is already used,
            # kill it with fire.
            if thing.server.clients[nick]
                thing.send :numeric, ERR_NICKNAMEINUSE, nick
            else
                thing.nick = nick

                # try to register it
                Utils::registration(thing)
            end
        else
            # if the user has already registered and the choosen nick is already used,
            # just tell him that he's a faggot.
            if thing.server.clients[nick]
                thing.send :numeric, ERR_NICKNAMEINUSE, nick
            else
                thing.server.clients.delete(thing.nick)

                mask       = thing.mask.to_s
                thing.nick = nick

                thing.server.clients[thing.nick] = thing

                if thing.channels.empty?
                    thing.send :raw, ":#{mask} NICK :#{nick}"
                else
                    thing.channels.unique_users.send :raw, ":#{mask} NICK :#{nick}"
                end
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

                # try to register it
                Utils::registration(thing)
            end
        elsif thing.is_a?(Link)

        end
    end

    def join (thing, string)
        match = string.match(/JOIN\s+(.+?)(\s+(.+))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'JOIN'
            return
        end

        channels  = match[1].split(/,/)
        passwords = (match[3] || '').split(/,/)

        channels.each {|channel|
            if !Utils::Channel::isValid(channel)
                channel = "##{channel}"
            end

            if !Utils::Channel::isValid(channel)
                thing.send :numeric, ERR_BADCHANMASK, channel
                return
            end

            if thing.channels[channel]
                return
            end

            if !thing.server.channels[channel]
                channel = thing.server.channels[channel] = Channel.new(server, channel)
                channel.modes[:type]    = channel.name[0, 1]
                channel.modes[:bans]    = []
                channel.modes[:invites] = []
            else
                channel = thing.server.channels[channel]
            end

            if channel.modes[:password]
                password = passwords.shift
            else
                password = ''
            end

            if channel.modes[:k] && password != channel.modes[:password]
                thing.send :numeric, ERR_BADCHANNELKEY, channel
                return 
            end

            if channel.modes[:i] && !Utils::Channel::invited?(channel, thing)
                thing.send :numeric, ERR_INVITEONLYCHAN, channel.name
                return
            end

            if Utils::Channel::banned?(channel, thing)
                thing.send :numeric, ERR_BANNEDFROMCHAN, channel.name
                return
            end

            empty = channel.empty?
            user  = channel.add(thing)

            if empty
                Utils::setMode @server, channel, "+o #{user.nick}", true
            end

            thing.channels.add(channel)

            if server.dispatcher.execute(:join, user) != false
                if !channel.topic.nil?
                    topic thing, "TOPIC #{channel}"
                end

                names thing, "NAMES #{channel}"
            else
                user.channel.delete(user)
                thing.channels.delete(channel)
            end
        }
    end

    def send_join (user)
        user.channel.send :raw, ":#{user.mask} JOIN :#{user.channel}"
    end

    def part (thing, string)
        match = string.match(/PART\s+(.+?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'PART'
            return
        end

        name    = match[1]
        message = match[3]
        channel = thing.server.channels[name]

        if !channel
            thing.send :numeric, ERR_NOSUCHCHANNEL, name
        elsif !thing.channels[name]
            thing.send :numeric, ERR_NOTONCHANNEL, name
        else
            if server.dispatcher.execute(:part, thing.channels[name].user(thing), message) != false
                channel.delete(thing)
                thing.channels.delete(name)
            end
        end
    end

    def send_part (user, message)
        if user.client.modes[:quitting]
            return
        end

        user.channel.send :raw, ":#{user.mask} PART #{user.channel} :#{message}"
    end

    def kick (thing, string)
        match = string.match(/KICK\s+(.+?)\s+(.+?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'KICK'
            return
        end

        channel = match[1]
        user    = match[2]
        message = match[4]

        if !Utils::Channel::isValid(channel)
            thing.send :numeric, ERR_BADCHANMASK, channel
            return
        end

        if !thing.server.channels[channel]
            thing.send :numeric, ERR_NOSUCHCHANNEL, channel
            return
        end

        if !thing.server.clients[user]
            thing.send :numeric, ERR_NOSUCHNICK, user
            return
        end

        channel = thing.server.channels[channel]
        user    = channel[user]

        if !user
            thing.send :numeric, ERR_NOTONCHANNEL, channel.name
            return
        end

        if thing.channels[channel.name]
            thing = thing.channels[channel.name].user(thing)
        end

        if thing.modes[:can_kick]
            if server.dispatcher.execute(:kick, thing, user, message) != false
                channel.delete(user)
                user.client.channels.delete(channel)
            end
        end
    end

    def send_kick (kicker, kicked, message)
        kicked.channel.send :raw, ":#{kicker.mask} KICK #{kicked.channel} #{kicked.nick} :#{message}"
    end

    def topic (thing, string)
        match = string.match(/TOPIC\s+(.*?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'TOPIC'
            return
        end

        channel = match[1]

        if !thing.modes[:can_change_topic] && !thing.channels[channel]
            thing.send :numeric, ERR_NOTONCHANNEL, thing.server.channels[channel]
        else
            if match[2]
                topic = match[3].to_s

                if thing.channels[channel].modes[:t] && (!thing.channels[channel].user(thing).modes[:can_change_topic] && !thing.modes[:can_change_topic])
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

    def send_topic (channel)
        channel.send :raw, ":#{channel.topic.setBy.mask} TOPIC #{channel} :#{channel.topic}"
    end

    def names (thing, string)
        match = string.match(/NAMES\s+(.*)$/i)

        if !match
            thing.send :numeric, RPL_ENDOFNAMES, thing.nick
            return
        end

        channel = match[1]

        if thing.channels[channel]
            thing.send :numeric, RPL_NAMREPLY, thing.channels[channel]
        end

        thing.send :numeric, RPL_ENDOFNAMES, channel
    end

    def who (thing, string)
        match = string.match(/WHO\s+(.*?)(\s+o)?$/i)

        name = match[1] || '*'

        if match
            op = match[2]

            if Utils::Channel::isValid(name) && thing.server.channels[name]
                thing.server.channels[name].users.each_value {|user|
                    thing.send :numeric, RPL_WHOREPLY, {
                        :channel => thing.server.channels[name],
                        :user    => user,
                        :hops    => 0,
                    }
                }
            else

            end
        end

        thing.send :numeric, RPL_ENDOFWHO, name
    end

    def privmsg (thing, string)
        match = string.match(/PRIVMSG\s+(.*?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NORECIPIENT, 'PRIVMSG'
            return
        end

        if !match[3]
            thing.send :numeric, ERR_NOTEXTTOSEND
        else
            receiver = match[1]
            message  = match[3]

            if Utils::Channel::isValid(receiver)
                channel = thing.channels[receiver] || thing.server.channels[receiver]

                if channel
                    user = channel.user(thing)

                    if channel.modes[:m] && !user.modes[:can_talk] && !thing.modes[:can_talk]
                        thing.send :numeric, ERR_YOUNEEDVOICE, channel.name
                        return
                    end

                    if Utils::Channel::banned?(channel, thing)
                        thing.send :numeric, ERR_YOUAREBANNED, channel.name
                        return
                    end

                    if user
                        thing.server.dispatcher.execute(:message, thing, channel, message)
                    else
                        if thing.server.channels[receiver].modes[:n]
                            thing.send :numeric, ERR_ERR_NOEXTERNALMESSAGES, channel.name
                        else
                            thing.server.dispatcher.execute(:message, thing, channel, message)
                        end
                    end
                else
                    thing.send :numeric, ERR_NOSUCHNICK, receiver
                end
            else
                client = thing.server.clients[receiver]

                if !client
                    thing.send :numeric, ERR_NOSUCHNICK, receiver
                else
                    thing.server.dispatcher.execute(:message, thing, client, message)
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

    def notice (thing, string)
        match = string.match(/NOTICE\s+(.*?)\s+:(.*)$/i)

        if match
            name    = match[1]
            message = match[2]

            if server.clients[name]
                thing.server.dispatcher.execute(:notice, thing, server.clients[name], message)
            elsif server.channels[name]
                thing.server.dispatcher.execute(:notice, thing, server.channels[name], message)
            else
                # unrealircd sends an error if it can't find nick/channel, what should I do?
            end
        end
    end

    def send_notice (sender, receiver, message)
        if sender.is_a?(User)
            sender = sender.client
        end

        receiver.send :raw, ":#{sender} NOTICE #{receiver.nick} :#{message}"
    end

    def map (thing, string)
        thing.server.dispatcher.execute(:notice, server, thing, 'The X tells the point.')
    end

    def version (thing, string)
        thing.send :numeric, RPL_VERSION
    end

    def quit (thing, string)
        match = /^QUIT((\s+)(:)?(.*)?)?$/i.match(string)

        user    = thing
        message = match[4] || user.nick
        text    = eval(@messages[:quit].inspect.gsub(/\\#/, '#'))

        thing.server.kill(thing, text)
    end

    def send_quit (thing, message)
        thing.channels.unique_users.send :raw, ":#{thing.mask} QUIT :#{message}"
    end 
end

end

end
