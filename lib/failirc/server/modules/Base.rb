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
    attr_reader :messages

    @@version = '0.0.1'

    def self.version
        return @@version
    end

    def description
        "Base-#{Base.version}"
    end

    def initialize (server)
        server.data[:nicks] = {}

        @pingedOut = ThreadSafeHash.new
        @toPing    = ThreadSafeHash.new

        @pingThread = Thread.new {
            while true
                # time to ping non active users
                @toPing.each_value {|client|
                    @pingedOut[client.socket] = client

                    if client.modes[:registered]
                        client.send :raw, "PING :#{server.host}"
                    end
                }

                # clear and refil the hash of clients to ping with all the connected clients
                @toPing.clear
                @toPing.merge!(::Hash[server.clients.values.collect {|client| [client.socket, client]}])

                sleep server.config.elements['config/server/pingTimeout'].text.to_i

                # people who didn't answer with a PONG has to YIFF IN HELL.
                @pingedOut.each_value {|client|
                    if !client.socket.closed?
                        server.dispatcher.execute(:error, client, 'Ping timeout', :close)
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

                :AWAY     => /^AWAY( |$)/i,
                :MODE     => /^MODE( |$)/i,
                :ENCODING => /^ENCODING( |$)/i,

                :PASS => /^PASS( |$)/i,
                :NICK => /^(:[^ ] )?NICK( |$)/i,
                :USER => /^(:[^ ] )?USER( |$)/i,

                :JOIN => /^(:[^ ] )?JOIN( |$)/i,
                :PART => /^(:[^ ] )?PART( |$)/i,
                :KICK => /^(:[^ ] )?KICK( |$)/i,

                :TOPIC => /^(:[^ ] )?TOPIC( |$)/i,
                :NAMES => /^NAMES( |$)/i,
                :LIST  => /^LIST( |$)/i,

                :WHO    => /^WHO( |$)/i,
                :WHOIS  => /^WHOIS( |$)/i,
                :WHOWAS => /^WHOWAS( |$)/i,

                :PRIVMSG => /^(:[^ ] )?PRIVMSG( |$)/i,
                :NOTICE  => /^NOTICE( |$)/i,

                :MAP     => /^MAP( |$)/i,
                :VERSION => /^VERSION( |$)/i,

                :OPER => /^OPER( |$)/i,
                :KILL => /^KILL( |$)/i,

                :QUIT => /^QUIT( |$)/i,
            },
        }

        @events = {
            :pre => self.method(:check),

            :custom => {
                :client_nick_change => self.method(:client_nick_change),

                :kill => self.method(:client_quit),

                :join => self.method(:user_join),
                :part => self.method(:user_part),
                :kick => self.method(:send_kick),

                :whois => self.method(:send_whois),

                :message => self.method(:send_message),
                :ctcp    => self.method(:send_ctcp),
                :notice  => self.method(:send_notice),
                :error   => self.method(:send_error),

                :topic_change => self.method(:send_topic),
            },

            :default => self.method(:unknown_command),

            :input => {
                :PING => self.method(:ping),
                :PONG => self.method(:pong),

                :AWAY     => self.method(:away),
                :MODE     => self.method(:mode),
                :ENCODING => self.method(:encoding),

                :PASS => self.method(:pass),
                :NICK => self.method(:nick),
                :USER => self.method(:user),

                :JOIN => self.method(:join),
                :PART => self.method(:part),
                :KICK => self.method(:kick),

                :TOPIC => self.method(:topic),
                :NAMES => self.method(:names),
                :LIST  => self.method(:list),

                :WHO    => self.method(:who),
                :WHOIS  => self.method(:whois),
                :WHOWAS => self.method(:whowas),

                :PRIVMSG => self.method(:privmsg),
                :NOTICE  => self.method(:notice),

                :MAP     => self.method(:map),
                :VERSION => self.method(:version),

                :OPER => self.method(:oper),
                :KILL => self.method(:kill),

                :QUIT => self.method(:quit),
            },
        }

        super(server)
    end

    def rehash
        if tmp = server.config.elements['config/modules/module[@name="Base"]/misc/nickAllowed']
            @nickAllowed = tmp.text
        else
            @nickAllowed = 'nick.match(/^[\w^`-]{1,23}$/)'
        end

        @messages = {}

        if tmp = server.config.elements['config/modules/module[@name="Base"]/messages/part']
            @messages[:part] = tmp.text
        else
            @messages[:part] = '#{message}'
        end

        if tmp = server.config.elements['config/modules/module[@name="Base"]/messages/quit']
            @messages[:quit] = tmp.text
        else
            @messages[:quit] = 'Quit: #{message}'
        end

        if tmp = server.config.elements['config/modules/module[@name="Base"]/messages/kill']
            @messages[:kill] = tmp.text
        else
            @messages[:kill] = 'Kill: #{(message && !message.empty?) ? message : \'No reason\'} (#{sender.nick})'
        end

        if tmp = server.config.elements['config/modules/module[@name="Base"]/messages/version']
            @messages[:version] = tmp.text
        else
            @messages[:version] = 'THE GAME'
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

            def self.type (string)
                string.match(/^([&#+!])/)
            end

            def self.isValid (string)
                string.match(/^[&#+!][^ ,:\a]{0,50}$/) ? true : false
            end
    
            def self.invited? (channel, client)
                if !channel.modes[:invite_only]
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

        module User
            @@levels = {
                :q => '~',
                :a => '&',
                :o => '@',
                :h => '%',
                :v => '+',
            }

            def self.getHighestLevel (user)
                if user.modes[:q]
                    return :q
                elsif user.modes[:a]
                    return :a
                elsif user.modes[:o]
                    return :o
                elsif user.modes[:h]
                    return :h
                elsif user.modes[:v]
                    return :v
                end
            end

            def self.setLevel (user, level, value)
                if @@levels[level]
                    Utils::setFlags(user, level, value)

                    if value
                        user.modes[:level] = @@levels[level]
                    else
                        self.setLevel(user, self.getHighestLevel(user), true)
                    end
                else
                    user.modes[:level] = ''
                end
            end
        end

        # This method does some checks trying to register the connection, various checks
        # for nick collisions and such.
        def self.registration (thing)
            if !thing.modes[:registered]
                # additional check for nick collisions
                if thing.nick
                    if (thing.server.data[:nicks][thing.nick] && thing.server.data[:nicks][thing.nick] != thing) || thing.server.clients[thing.nick]
                        if thing.modes[:__warned] != thing.nick
                            thing.send :numeric, ERR_NICKNAMEINUSE, thing.nick
                            thing.modes[:__warned] = thing.nick
                        end

                        return
                    end

                    thing.server.data[:nicks][thing.nick] = thing
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

                    thing.server.data[:nicks].delete(thing.nick)
                    thing.modes.delete(:__warned)
    
                    thing.server.dispatcher.execute(:registration, thing)
    
                    thing.send :numeric, RPL_WELCOME, thing
                    thing.send :numeric, RPL_HOSTEDBY, thing
                    thing.send :numeric, RPL_SERVCREATEDON
                    thing.send :numeric, RPL_SERVINFO
    
                    motd(thing)
                end
            end
        end

        # This method sends the MOTD 80 chars per line.
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
            :groups => {
                :can_change_channel_modes => [
                    :can_change_channel_extended_modes, :can_change_topic_mode,
                    :can_change_no_external_messages_mode, :can_change_secret_mode,
                    :can_change_ssl_mode, :can_change_moderated_mode,
                    :can_change_invite_only_mode
                ],

                :can_change_user_modes => [
                    :can_give_channel_operator, :can_give_channel_half_operator,
                    :can_give_voice, :can_change_user_extended_modes
                ],

                :can_change_client_modes => [
                    :can_change_client_extended_modes
                ],
            },

            :channel => {
                :a => :anonymous,
                :i => :invite_only,
                :m => :moderated,
                :n => :no_external_messages,
                :s => :secret,
                :t => :topic_change_needs_privileges,
                :z => :ssl_only,
            },

            :user => {
                :a => [:o, :admin],
                :o => [:h, :operator, :can_change_topic, :can_change_channel_modes, :can_change_user_modes],
                :h => [:v, :halfoperator, :can_kick],
                :v => [:voice, :can_talk],
            },

            :client => {
                :netadmin => [:N, :operator],
                :operator => [:o, :can_kill, :can_kick, :can_change_topic, :can_change_channel_modes, :can_change_user_modes, :can_change_client_modes],

                :N => [:netadmin],
                :o => [:operator],
            },
        }

        # This method assigns flags recursively using groups of flags
        def self.setFlags (thing, type, value)
            if @@modes[:groups][type]
                main = @@modes[:groups]
            else
                if thing.is_a?(IRC::Channel)
                    main = @@modes[:channel]
                elsif thing.is_a?(IRC::User)
                    main = @@modes[:user]
                elsif thing.is_a?(IRC::Client)
                    main = @@modes[:client]
                else
                    raise 'What sould I do?'
                end
            end

            if value == false
                thing.modes.delete(type)
            else
                thing.modes[type] = value
            end

            if !(modes = main[type])
                return
            end

            if !modes.is_a?(Array)
                modes = [modes]
            end

            modes.each {|mode|
                if (main[mode] || @@modes[:groups][mode]) && !thing.modes.has_key?(mode)
                    self.setFlags(thing, mode, value)
                else
                    if value == false
                        if !main.has_key?(mode)
                            thing.modes.delete(mode)
                        end
                    else
                        thing.modes[mode] = value
                    end
                end
            }
        end

        def self.checkFlag (thing, type)
            # servers can do everything
            if thing.is_a?(IRC::Server)
                return true
            end

            result = thing.modes[type]

            if !result && thing.is_a?(IRC::User)
                result = thing.client.modes[type]
            end

            return result
        end

        def self.setMode (from, thing, request, noAnswer=false)
            if match = request.match(/^=(.*)$/)
                value = match[1].strip

                if thing.is_a?(IRC::Channel) && !self.checkFlag(from, :can_change_channel_extended_modes)
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                    return
                elsif thing.is_a?(IRC::User) && !self.checkFlag(from, :can_change_user_extended_modes)
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.channel.name
                    return
                elsif thing.is_a?(IRC::Client) && from.nick != thing.nick && !self.checkFlag(from, :can_change_client_extended_modes) && !self.checkFlag(from, :frozen)
                    from.send :numeric, ERR_NOPRIVILEGES
                    return
                end

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
                else
                    modes = value.split(/[^\\],/)
    
                    modes.each {|mode|
                        if mode[0, 1] == '-'
                            type = '-'
                        else
                            type = '+'
                        end
    
                        mode.sub!(/^[+\-]/, '')
    
                        mode = mode.split(/=/)

                        if !mode[0].match(/^\w+$/)
                            from.server.dispatcher.execute :error, from, "#{mode[0]} is not a valid extended mode."
                            next
                        end
    
                        if type == '+'
                            thing.modes[:extended][mode[0].to_sym] = mode[1] || true
                        else
                            thing.modes[:extended].delete(mode[0].to_sym)
                        end
                    }
                end
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

                        when 'h'
                            if self.checkFlag(from, :can_give_channel_half_operator)
                                value = values.shift

                                if !(user = thing.users[value])
                                    from.send :numeric, ERR_NOSUCHNICK, value
                                    next
                                end

                                if type == '+'
                                    if user.modes[:h]
                                        next
                                    end

                                    User::setLevel(user, :h, true)
                                else
                                    if !user.modes[:h]
                                        next
                                    end
                                    
                                    User::setLevel(user, :h, false)
                                end

                                outputModes.push('h')
                                outputValues.push(value)
                            else
                                from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                            end

                        when 'i'
                            if self.checkFlag(from, :can_change_invite_only_mode)
                                if self.checkFlag(thing, :i) == (type == '+')
                                    next
                                end

                                self.setFlags(thing, :i, type == '+')

                                outputModes.push('i')
                            end

                        when 'm'
                            if self.checkFlag(from, :can_change_moderated_mode)
                                if self.checkFlag(thing, :m) == (type == '+')
                                    next
                                end

                                self.setFlags(thing, :m, type == '+')

                                outputModes.push('m')
                            else
                                from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                            end

                        when 'n'
                            if self.checkFlag(from, :can_change_no_external_messages_mode)
                                if self.checkFlag(thing, :n) == (type == '+')
                                    next
                                end

                                self.setFlags(thing, :n, type == '+')

                                outputModes.push('n')
                            else
                                from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                            end

                        when 'o'
                            if self.checkFlag(from, :can_give_channel_operator)
                                value = values.shift

                                if !(user = thing.users[value])
                                    from.send :numeric, ERR_NOSUCHNICK, value
                                    next
                                end

                                if type == '+'
                                    if user.modes[:o]
                                        next
                                    end

                                    self.setFlags(user, :o, true)

                                    if !user.modes[:q] && !user.modes[:a]
                                        user.modes[:level] = '@'
                                    end
                                else
                                    if !user.modes[:o]
                                        next
                                    end
                                    
                                    self.setFlags(user, :o, false)
                                end

                                outputModes.push('o')
                                outputValues.push(value)
                            else
                                from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                            end

                        when 's'
                            if self.checkFlag(from, :can_change_secret_mode)
                                if self.checkFlag(thing, :s) == (type == '+')
                                    next
                                end

                                self.setFlags(thing, :s, type == '+')

                                outputModes.push('s')
                            else
                                from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                            end

                        when 't'
                            if self.checkFlag(from, :can_change_topic_mode)
                                if self.checkFlag(thing, :t) == (type == '+')
                                    next
                                end

                                self.setFlags(thing, :t, type == '+')

                                outputModes.push('t')
                            else
                                from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                            end

                        when 'v'
                            if self.checkFlag(from, :can_give_voice)
                                value = values.shift

                                if !(user = thing.users[value])
                                    from.send :numeric, ERR_NOSUCHNICK, value
                                    next
                                end

                                if type == '+'
                                    if user.modes[:v]
                                        next
                                    end

                                    self.setFlags(user, :v, true)

                                    if !user.modes[:q] && !user.modes[:a] && !user.modes[:o] && !user.modes[:h]
                                        user.modes[:level] = '+'
                                    end
                                else
                                    if !user.modes[:v]
                                        next
                                    end
                                    
                                    self.setFlags(user, :v, false)
                                end

                                outputModes.push('v')
                                outputValues.push(value)
                               
                            else
                                from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                            end

                        when 'z'
                            if self.checkFlag(from, :can_change_ssl_mode)
                                if self.checkFlag(thing, :z) == (type == '+')
                                    next
                                end

                                if type == '+'
                                    ok = true

                                    thing.users.each_value {|user|
                                        if !self.checkFlag(user, :ssl)
                                            ok = false
                                            break
                                        end
                                    }

                                    if ok
                                        self.setFlags(thing, :z, true)
                                    else
                                        from.send :numeric, ERR_ALLMUSTUSESSL
                                        next
                                    end
                                else
                                    self.setFlags(thing, :z, false)
                                end

                                outputModes.push('z')
                            else
                                from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                            end
                        end
                    elsif thing.is_a?(IRC::Client)
                    end

                    if from.is_a?(IRC::Client) || from.is_a?(IRC::User)
                        from = from.mask
                    end

                    if !noAnswer && (!outputModes.empty? || !outputValues.empty?)
                        thing.send :raw, ":#{from} MODE #{thing.is_a?(IRC::Channel) ? thing.name : thing.nick} #{type}#{outputModes.join('')} #{outputValues.join(' ')}"
                    end
                }
            end
        end

        def self.dispatchMessage (from, to, message)
            if match = message.match(/^\x01([^ ]*)( (.*?))?\x01$/)
                from.server.dispatcher.execute(:ctcp, from, to, match[1], match[2] ? match[3] : nil)
            else
                from.server.dispatcher.execute(:message, from, to, message)
            end
        end

        def self.escapeMessage (string)
            string.inspect.gsub(/\\#/, '#').gsub(/\\'/, "'")
        end
    end

    def check (event, thing, string)
        if event.chain != :input || !thing || !string
            return
        end

        @toPing.delete(thing.socket)
        @pingedOut.delete(thing.socket)

        if event.alias != :PING && event.alias != :PONG && event.alias != :WHO && event.alias != :MODE
            thing.modes[:last_action] = Utils::Client::Action.new(thing, event, string)
        end

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

        thing.send :raw, ":#{server.host} PONG #{server.host} :#{match[1]}"

        # RFC isn't that clear about when this error should be shoot
        # thing.send :numeric, ERR_NOSUCHSERVER, match[1]
    end

    def pong (thing, string)
        match = string.match(/PONG\s+(:)?(.*)$/i)

        if !match
            thing.send :numeric, ERR_NOORIGIN
            return
        end

        if match[2] == server.host
            @pingedOut.delete(thing.socket)
        else
            thing.send :numeric, ERR_NOSUCHSERVER, match[2]
        end
    end

    def away (thing, string)
        match = string.match(/AWAY\s+(:)?(.*)$/i)

        if !match || match[2].empty?
            thing.modes[:away] = false
            thing.send :numeric, RPL_UNAWAY
        else
            thing.modes[:away] = match[2]
            thing.send :numeric, RPL_NOWAWAY
        end
    end

    def mode (thing, string)
        # MODE user/channel = +option,-option
        match = string.match(/MODE\s+([^ ]+)(\s+(:)?(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'MODE'
            return
        end

        name  = match[1]
        value = match[4] || ''

        # long options, extended protocol
        if match = value.match(/^=\s+(.*)$/)
            if Utils::Channel::isValid(name)
                channel = server.channels[name]

                if channel
                    Utils::setMode(channel.user(thing) || thing, channel, value)
                else
                    thing.send :numeric, ERR_NOSUCHCHANNEL, name
                end
            elsif match = name.match(/^([^@])@(.*)$/)
                user    = match[1]
                channel = match[2]

                if tmp = server.channels[channel]
                    channel = tmp

                    if tmp = server.clients[user]
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
                if tmp = server.clients[name]
                    client = tmp

                    Utils::setMode(thing, client, value)
                else
                    thing.send :numeric, ERR_NOSUCHNICK, name
                end
            end
        # usual shit
        else
            if Utils::Channel::isValid(name)
                if server.channels[name]
                    channel = server.channels[name]

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
                if server.clients[name]
                    Utils::setMode(thing, server.clients[name], value)
                else
                    thing.send :numeric, ERR_NOSUCHNICK, name
                end
            end
        end
    end

    def encoding (thing, string)
        match = string.match(/ENCODING\s+(.+)$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'ENCODING'
            return
        end

        name = match[1].strip

        begin
            "".encode(name)
            thing.modes[:encoding] = name
        rescue Encoding::ConverterNotFoundError
            server.dispatcher.execute(:error, thing, "#{name} is not a valid encoding.")
        end
    end

    def pass (thing, string)
        match = string.match(/PASS\s+(:)?(.+)$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'PASS'
        else
            thing.password = match[2]

            if thing.listen.attributes['password']
                if thing.password != thing.listen.attributes['password']
                    server.dispatcher.execute(:error, thing, :close, 'Password mismatch')
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

        match = string.match(/NICK\s+(:)?(.+)$/i)

        # no nickname was passed, so tell the user is a faggot
        if !match
            thing.send :numeric, ERR_NONICKNAMEGIVEN
            return
        end

        nick = match[2].strip

        if server.dispatcher.execute(:client_nick_change, thing, nick) == false
            return
        end

        if !thing.modes[:registered]
            # if the user hasn't registered yet and the choosen nick is already used,
            # kill it with fire.
            if server.clients[nick] || server.data[:nicks][nick]
                thing.send :numeric, ERR_NICKNAMEINUSE, nick
                thing.modes[:__warned] = nick
            else
                if thing.nick
                    server.data[:nicks].delete(thing.nick)
                end

                thing.nick = nick

                # try to register it
                Utils::registration(thing)
            end
        else
            # if the user has already registered and the choosen nick is already used,
            # just tell him that he's a faggot.
            if server.clients[nick] || server.data[:nicks][nick]
                thing.send :numeric, ERR_NICKNAMEINUSE, nick
            else
                server.data[:nicks].delete(nick)

                mask       = thing.mask.clone
                thing.nick = nick

                server.clients[thing.nick] = server.clients.delete(mask.nick)

                thing.channels.each_value {|channel|
                    channel.users.add(channel.users.delete(mask.nick))
                }

                if thing.channels.empty?
                    thing.send :raw, ":#{mask} NICK :#{nick}"
                else
                    thing.channels.unique_users.send :raw, ":#{mask} NICK :#{nick}"
                end
            end
        end
    end

    def client_nick_change (thing, nick)
        allowed = eval(@nickAllowed) rescue false

        if !allowed
            thing.send :numeric, ERR_ERRONEUSNICKNAME, nick
            return false
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

        if match[1] == '0'
            thing.channels.each_value {|channel|
                server.dispatcher.execute :part, channel[thing.nick], 'Left all channels'
            }

            return
        end

        channels  = match[1].split(/,/)
        passwords = (match[3] || '').split(/,/)

        channels.each {|channel|
            if !Utils::Channel::type(channel)
                channel = "##{channel}"
            end

            if !Utils::Channel::isValid(channel)
                thing.send :numeric, ERR_BADCHANMASK, channel
                return
            end

            if thing.channels[channel]
                return
            end

            if !server.channels[channel]
                channel = server.channels[channel] = Channel.new(server, channel)
                channel.modes[:type]    = channel.name[0, 1]
                channel.modes[:bans]    = []
                channel.modes[:invites] = []
            else
                channel = server.channels[channel]
            end

            if channel.modes[:password]
                password = passwords.shift
            else
                password = ''
            end

            if channel.modes[:ssl_only] && !thing.modes[:ssl]
                thing.send :numeric, ERR_SSLREQUIRED, channel.name
                return
            end

            if channel.modes[:password] && password != channel.modes[:password]
                thing.send :numeric, ERR_BADCHANNELKEY, channel
                return 
            end

            if channel.modes[:invite_only] && !Utils::Channel::invited?(channel, thing)
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

            if server.dispatcher.execute(:join, user) == false
                user.channel.delete(user)
                thing.channels.delete(channel)
            end
        }
    end

    def user_join (user)
        user.channel.send :raw, ":#{user.mask} JOIN :#{user.channel}"

        if !user.channel.topic.nil?
            topic user.client, "TOPIC #{user.channel}"
        end

        names user.client, "NAMES #{user.channel}"
    end

    def part (thing, string)
        match = string.match(/PART\s+(.+?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'PART'
            return
        end

        names   = match[1].split(/,/)
        message = match[3]

        names.each {|name|
            if !Utils::Channel::type(name)
                name = "##{name}"
            end

            channel = server.channels[name]

            if !channel
                thing.send :numeric, ERR_NOSUCHCHANNEL, name
            elsif !thing.channels[name]
                thing.send :numeric, ERR_NOTONCHANNEL, name
            else
                server.dispatcher.execute(:part, channel.user(thing), message)
            end
        }
    end

    def user_part (user, message)
        if user.client.modes[:quitting]
            return false
        end

        text = eval(Utils::escapeMessage(@messages[:part]))

        user.channel.send :raw, ":#{user.mask} PART #{user.channel} :#{text}"

        user.channel.delete(user)
        user.client.channels.delete(user.channel.name)
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

        if !server.channels[channel]
            thing.send :numeric, ERR_NOSUCHCHANNEL, channel
            return
        end

        if !server.clients[user]
            thing.send :numeric, ERR_NOSUCHNICK, user
            return
        end

        channel = server.channels[channel]
        user    = channel[user]

        if !user
            thing.send :numeric, ERR_NOTONCHANNEL, channel.name
            return
        end

        if thing.channels[channel.name]
            thing = thing.channels[channel.name].user(thing)
        end

        if thing.modes[:can_kick]
            server.dispatcher.execute(:kick, thing, user, message)
        else
            thing.send :numeric, ERR_CHANOPRIVSNEEDED, channel.name
        end
    end

    def send_kick (kicker, kicked, message)
        kicked.channel.send :raw, ":#{kicker.mask} KICK #{kicked.channel} #{kicked.nick} :#{message}"

        kicked.channel.delete(kicked)
        kicked.client.channels.delete(kicked.channel)
    end

    def topic (thing, string)
        match = string.match(/TOPIC\s+(.*?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'TOPIC'
            return
        end

        channel = match[1].strip

        if !Utils::checkFlag(thing, :can_change_topic) && !thing.channels[channel]
            thing.send :numeric, ERR_NOTONCHANNEL, server.channels[channel]
        else
            if match[2]
                topic = match[3].to_s

                if thing.channels[channel].modes[:t] && !Utils::checkFlag(thing.channels[channel].user(thing), :can_change_topic)
                    thing.send :numeric, ERR_CHANOPRIVSNEEDED, server.channels[channel]
                else
                    thing.channels[channel].topic = [thing, topic]
                end
            else
                if thing.channels[channel].topic.nil?
                    thing.send :numeric, RPL_NOTOPIC, server.channels[channel]
                else
                    thing.send :numeric, RPL_TOPIC, server.channels[channel].topic
                    thing.send :numeric, RPL_TOPICSETON, thing.channels[channel].topic
                end
            end
        end
    end

    def send_topic (channel)
        channel.send :raw, ":#{channel.topic.setBy} TOPIC #{channel} :#{channel.topic}"
    end

    def names (thing, string)
        match = string.match(/NAMES\s+(.*)$/i)

        if !match
            thing.send :numeric, RPL_ENDOFNAMES, thing.nick
            return
        end

        channel = match[1].strip

        if thing.channels[channel]
            users = String.new

            if thing.channels[channel].modes[:auditorium]
                thing.channels[channel].users.each_value {|user|
                    if user.modes[:level]
                        users << " #{user}"
                    end
                }
            else
                thing.channels[channel].users.each_value {|user|
                    users << " #{user}"
                }
            end

            users = users[1, users.length]

            thing.send :numeric, RPL_NAMREPLY, {
                :channel => channel,
                :users   => users,
            }
        end

        thing.send :numeric, RPL_ENDOFNAMES, channel
    end

    def list (thing, string)
        match = string.match(/LIST(\s+(.*))?$/)

        channels = (match[2].strip || '').split(/,/)

        thing.send :numeric, RPL_LISTSTART

        if channels.empty?
            channels = server.channels
        else
            tmp = Channels.new(thing.server)

            channels.each {|channel|
                if channel = server.channels[channel]
                    tmp.add(channel)
                end
            }

            channels = tmp
        end

        channels.each_value {|channel|
            if !channel.modes[:secret] || thing.channels[channel.name]
                thing.send :numeric, RPL_LIST, channel
            end
        }

        thing.send :numeric, RPL_LISTEND
    end

    def who (thing, string)
        match = string.match(/WHO\s+(.*?)(\s+o)?$/i)

        name = match[1].strip || '*'

        if match
            op = match[2]

            if Utils::Channel::isValid(name) && server.channels[name]
                channel = server.channels[name]

                channel.users.each_value {|user|
                    thing.send :numeric, RPL_WHOREPLY, {
                        :channel => channel,
                        :user    => user,
                        :hops    => 0,
                    }
                }
            else

            end
        end

        thing.send :numeric, RPL_ENDOFWHO, name
    end

    def whois (thing, string)
        match = string.match(/WHOIS\s+(.+?)(\s+(.+?))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'WHOIS'
            return
        end

        names  = (match[3] || match[1]).strip.split(/,/)
        server = match[3] ? match[1].strip : nil

        names.each {|name|
            thing.server.dispatcher.execute(:whois, thing, name)
        }
    end

    def send_whois (thing, name)
        if !server.clients[name]
            thing.send :numeric, ERR_NOSUCHNICK, name
            return
        end

        client = server.clients[name]

        thing.send :numeric, RPL_WHOISUSER, client

        if !client.channels.empty?
            channels = ''

            client.channels.each_value {|channel|
                if !channel.modes[:secret] || thing.channels[channel.name]
                    channels << " #{channel.user(client).modes[:level]}#{channel.name}"
                end
            }

            channels = channels[1, channels.length]

            thing.send :numeric, RPL_WHOISCHANNELS, {
                :nick     => client.nick,
                :channels => channels,
            }
        end

        thing.send :numeric, RPL_WHOISSERVER, client

        if client.modes[:ssl]
            thing.send :numeric, RPL_USINGSSL, client
        end

        if client.modes[:away]
            thing.send :numeric, RPL_AWWAY, client
        end

        if client.modes[:message]
            thing.send :numeric, RPL_WHOISOPERATOR, client
        end

        thing.send :numeric, RPL_WHOISIDLE, client
        thing.send :numeric, RPL_ENDOFWHOIS, client
    end

    def whowas (thing, string)
        thing.send :raw, 'PHONE'
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
                channel = thing.channels[receiver] || server.channels[receiver]

                if channel
                    user = channel.user(thing)

                    if channel.modes[:moderated] && !Utils::checkFlag(user, :can_talk)
                        thing.send :numeric, ERR_YOUNEEDVOICE, channel.name
                        return
                    end

                    if Utils::Channel::banned?(channel, thing)
                        thing.send :numeric, ERR_YOUAREBANNED, channel.name
                        return
                    end

                    if user
                        Utils::dispatchMessage(thing, channel, message)
                    else
                        if server.channels[receiver].modes[:no_external_messages]
                            thing.send :numeric, ERR_NOEXTERNALMESSAGES, channel.name
                        else
                            Utils::dispatchMessage(thing, channel, message)
                        end
                    end
                else
                    thing.send :numeric, ERR_NOSUCHNICK, receiver
                end
            else
                client = server.clients[receiver]

                if !client
                    thing.send :numeric, ERR_NOSUCHNICK, receiver
                else
                    Utils::dispatchMessage(thing, client, message)
                end
            end
        end
    end

    def send_message (from, to, message)
        if to.is_a?(Channel)
            to.users.each_value {|user|
                if user.mask != from.mask
                    user.send :raw, ":#{from.mask} PRIVMSG #{to.name} :#{message}"
                end
            }
        elsif to.is_a?(Client) || to.is_a?(User)
            to.send :raw, ":#{from.mask} PRIVMSG #{to.nick} :#{message}"
        end
    end

    def send_ctcp (from, to, type, message)
        if message
            text = "#{type} #{message}"
        else
            text = type
        end

        if to.is_a?(Channel)
            to.users.each_value {|user|
                if user.mask != from.mask
                    user.send :raw, ":#{from.mask} PRIVMSG #{to.name} :\x01#{text}\x01"
                end
            }
        elsif to.is_a?(Client) || to.is_a?(User)
            to.send :raw, ":#{from.mask} PRIVMSG #{to.nick} :\x01#{text}\x01"
        end

    end

    def notice (thing, string)
        match = string.match(/NOTICE\s+(.*?)\s+:(.*)$/i)

        if match
            name    = match[1]
            message = match[2]

            if client =server.clients[name]
                server.dispatcher.execute(:notice, thing, client, message)
            elsif channel = server.channels[name]
                if !channel.modes[:no_external_messages] || channel.user(thing)
                    server.dispatcher.execute(:notice, thing, channel, message)
                end
            else
                # unrealircd sends an error if it can't find nick/channel, what should I do?
            end
        end
    end

    def send_notice (sender, receiver, message)
        if sender.is_a?(User)
            sender = sender.client
        end

        if receiver.is_a?(Channel)
            name = receiver.name
        elsif receiver.is_a?(Client) || receiver.is_a?(User)
            name = receiver.nick
        end

        receiver.send :raw, ":#{sender} NOTICE #{name} :#{message}"
    end

    def send_error (thing, message, type=nil)
        case type
            when :close
                send_error(thing, "Closing Link: #{thing.nick}[#{thing.ip}] (#{message})")
            else
                thing.send :raw, "ERROR :#{message}"
        end
    end

    def map (thing, string)
        server.dispatcher.execute(:notice, server, thing, 'The X tells the point.')
    end

    def version (thing, string)
        comments = eval(Utils::escapeMessage(@messages[:version]))

        thing.send :numeric, RPL_VERSION
    end

    def oper (thing, string)
        match = string.match(/OPER\s+(.*?)(\s+(.*?))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'OPER'
            return
        end

        password = match[3] || match[1]
        name     = (match[3]) ? match[1] : nil

        server.config.elements['config/operators'].elements.each('operator') {|element|
            if thing.mask.match(element.attributes['mask']) && password == element.attributes['password']
                element.attributes['flags'].split(/,/).each {|flag|
                    Utils::setFlags(thing, flag.to_sym, true)
                }

                thing.modes[:message] = 'is an IRC operator'

                thing.send :numeric, RPL_YOUREOPER
                thing.send :raw, ":#{server} MODE #{thing.nick} #{thing.modes}"
                return
            end
        }

        thing.send :numeric, ERR_NOOPERHOST
    end

    def kill (thing, string)
        match = string.match(/KILL\s+(.*?)(\s+(:)?(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'KILL'
            return
        end

        if !Utils::checkFlag(thing, :can_kill)
            thing.send :numeric, ERR_NOPRIVILEGES
            return
        end

        nick    = match[1]
        client  = server.clients[nick]
        message = match[4]

        if !client
            thing.send :numeric, ERR_NOSUCHNICK, nick
            return
        end

        sender = thing

        text = eval(Utils::escapeMessage(@messages[:kill]))

        client.send :raw, ":#{client.mask} QUIT :#{text}"

        server.kill client, text
    end

    def quit (thing, string)
        match = /^QUIT((\s+)(:)?(.*)?)?$/i.match(string)

        user    = thing
        message = match[4] || user.nick
        text    = eval(Utils::escapeMessage(@messages[:quit]))

        server.kill(thing, text)
    end

    def client_quit (thing, message)
        server.data[:nicks].delete(thing.nick)

        thing.channels.unique_users.send :raw, ":#{thing.mask} QUIT :#{message}"
    end 
end

end

end
