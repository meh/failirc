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
require 'failirc/errors'
require 'failirc/responses'

require 'failirc/module'

require 'failirc/server/incoming'
require 'failirc/server/server'
require 'failirc/server/client'
require 'failirc/server/channel'
require 'failirc/server/user'

module IRC

class Server

module Modules

class Base < Module
    attr_reader :messages

    @@version = '0.0.1'

    @@modes = {
        :groups => {
            :can_change_channel_modes => [
                :can_change_channel_extended_modes, :can_change_topic_mode,
                :can_change_no_external_messages_mode, :can_change_secret_mode,
                :can_change_ssl_mode, :can_change_moderated_mode,
                :can_change_invite_only_mode, :can_change_auditorium_mode,
                :can_change_anonymous_mode, :can_change_limit_mode,
                :can_change_redirect_mode, :can_change_noknock_mode,
                :can_add_invitation, :can_channel_ban, :can_add_ban_exception,
                :can_change_channel_password, :can_change_nocolors_mode,
                :can_change_noctcp_mode, :can_change_no_nick_change_mode,
                :can_change_nokicks_mode, :can_change_strip_colors_mode,
                :can_change_noinvites_mode,
            ],

            :can_change_user_modes => [
                :can_give_channel_operator, :can_give_channel_half_operator,
                :can_give_voice, :can_change_user_extended_modes,
            ],

            :can_change_client_modes => [
                :can_change_client_extended_modes,
            ],
        },

        :channel => {
            :a => :anonymous,
            :c => :no_colors,
            :C => :no_ctcps,
            :i => :invite_only,
            :l => :limit,
            :L => :redirect,
            :k => :password,
            :K => :no_knock,
            :m => :moderated,
            :n => :no_external_messages,
            :N => :no_nick_change,
            :Q => :no_kicks,
            :s => :secret,
            :S => :strip_colors,
            :t => :topic_change_needs_privileges,
            :u => :auditorium,
            :V => :no_invites,
            :z => :ssl_only,
        },

        :user => {
            :x => [:y, :can_give_channel_admin],
            :y => [:o, :admin],
            :o => [:h, :operator, :can_change_topic, :can_invite, :can_change_channel_modes, :can_change_user_modes],
            :h => [:v, :halfoperator, :can_kick],
            :v => [:voice, :can_talk],
        },

        :client => {
            :netadmin => [:N, :operator],
            :operator => [:o, :can_kill, :can_give_channel_owner, :can_change_channel_modes, :can_change_user_modes, :can_change_client_modes],
        },
    }

    @@supportedModes = {
        :client  => [],
        :channel => [],
    }

    @@support = {}

    def self.version
        @@version
    end

    def self.modes
        @@modes
    end

    def self.supportedModes
        @@supportedModes
    end

    def self.support
        @@support
    end

    def description
        "Base-#{Base.version}"
    end

    def initialize (server)
        @aliases = {
            :input => {
                :PASS => /^PASS( |$)/i,
                :NICK => /^(:[^ ] )?NICK( |$)/i,
                :USER => /^(:[^ ] )?USER( |$)/i,

                :PING => /^PING( |$)/i,
                :PONG => /^PONG( |$)/i,

                :AWAY     => /^AWAY( |$)/i,
                :MODE     => /^MODE( |$)/i,
                :ENCODING => /^ENCODING( |$)/i,

                :JOIN   => /^(:[^ ] )?JOIN( |$)/i,
                :PART   => /^(:[^ ] )?PART( |$)/i,
                :KICK   => /^(:[^ ] )?KICK( |$)/i,
                :INVITE => /^INVITE( |$)/i,
                :KNOCK  => /^KNOCK( |$)/i,

                :TOPIC => /^(:[^ ] )?TOPIC( |$)/i,
                :NAMES => /^NAMES( |$)/i,
                :LIST  => /^LIST( |$)/i,

                :WHO    => /^WHO( |$)/i,
                :WHOIS  => /^WHOIS( |$)/i,
                :WHOWAS => /^WHOWAS( |$)/i,
                :ISON   => /^ISON( |$)/i,

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
            :pre  => [Event::Callback.new(self.method(:input_encoding), -1234567890), self.method(:check)],
            :post => [Event::Callback.new(self.method(:output_encoding), 1234567890)],

            :custom => {
                :nick => self.method(:handle_nick),

                :join   => self.method(:handle_join),
                :part   => self.method(:handle_part),
                :kick   => self.method(:handle_kick),
                :invite => self.method(:client_invite),

                :joined => self.method(:client_join),
                :parted => self.method(:user_part),
                :kicked => self.method(:send_kick),
                :killed => self.method(:client_quit),

                :whois => self.method(:handle_whois),

                :message => [self.method(:handling_message), self.method(:send_message)],
                :notice  => [self.method(:handling_notice), self.method(:send_notice)],
                :ctcp    => [self.method(:handling_ctcp), self.method(:send_ctcp)],
                :error   => self.method(:send_error),

                :topic_change => self.method(:topic_change),

                :mode => [self.method(:normal_mode), self.method(:extended_mode)],
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

                :JOIN   => self.method(:join),
                :PART   => self.method(:part),
                :KICK   => self.method(:kick),
                :INVITE => self.method(:invite),
                :KNOCK  => self.method(:knock),

                :TOPIC => self.method(:topic),
                :NAMES => self.method(:names),
                :LIST  => self.method(:list),

                :WHO    => self.method(:who),
                :WHOIS  => self.method(:whois),
                :WHOWAS => self.method(:whowas),
                :ISON   => self.method(:ison),

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

        server.data[:nicks] = {}

        @@supportedModes[:client].insert(-1, *('o'.split(//)))
        @@supportedModes[:channel].insert(-1, *('abcCehiIkKlLmnNoQsStuvVxyz'.split(//)))

        @@support.merge!({
            'CASEMAPPING' => 'ascii',
            'SAFELIST'    => true,
            'EXCEPTS'     => 'e',
            'INVEX'       => 'I',
            'CHANTYPES'   => '&#+!',
            'CHANMODES'   => 'beI,kfL,lj,acCiKmnNQsStuVz',
            'PREFIX'      => '(xyohv)~&@%+',
            'STATUSMSG'   => '~&@%+',
            'FNC'         => true,

            'CMDS' => 'KNOCK',
        })

        @joining   = ThreadSafeHash.new
        @semaphore = Mutex.new

        @pingedOut = ThreadSafeHash.new
        @toPing    = ThreadSafeHash.new

        @pingInterval = server.dispatcher.setInterval Fiber.new {
            while true
                # time to ping non active users
                @toPing.each_value {|thing|
                    @pingedOut[thing.socket] = thing

                    if thing.class != Incoming
                        thing.send :raw, "PING :#{server.host}"
                    end
                }

                # clear and refil the hash of clients to ping with all the connected clients
                @toPing.clear
                @toPing.merge!(server.connections.things)

                Fiber.yield

                # people who didn't answer with a PONG has to YIFF IN HELL.
                @pingedOut.each_value {|thing|
                    if !thing.socket.closed?
                        server.kill thing, 'Ping timeout', true
                    end
                }

                @pingedOut.clear
            end
        }, (@pingTimeout / 2.0)
    end

    def rehash
        if tmp = server.config.elements['config/modules/module[@name="Base"]/misc/pingTimeout']
            @pingTimeout = tmp.text.to_f
        else
            @pingTimeout = 60
        end

        if tmp = server.config.elements['config/modules/module[@name="Base"]/misc/nickAllowed']
            @nickAllowed = tmp.text
        else
            @nickAllowed = 'nick.match(/^[\w^`-]{1,23}$/)'
        end

        if tmp = server.config.elements['config/modules/module[@name="Base"]/misc/motd']
            @motd = tmp.text.strip
        else
            @motd = 'Welcome to a Fail IRC.'
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
        server.dispatcher.clearInterval @pingInterval
    end

    module Utils
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
            class Modifier
                attr_reader :setBy, :setOn, :channel, :mask

                def initialize (by, channel, mask)
                    @setBy   = by
                    @setOn   = Time.now
                    @channel = channel
                    @mask    = mask
                end

                def == (mask)
                    @mask == mask
                end

                def match (mask)
                    @mask.match(mask)
                end

                def to_s
                    "#{channel} #{mask} #{setBy.nick} #{setOn.tv_sec}"
                end
            end

            def self.type (string)
                string.match(/^([&#+!])/)
            end

            def self.isValid (string)
                if !string
                    return false
                end

                string.match(/^[&#+!][^ ,:\a]{0,50}$/) ? true : false
            end
    
            def self.invited? (channel, client, shallow=false)
                if shallow && !channel.modes[:invite_only]
                    return true
                end

                if channel.modes[:invited].has_value?(client.nick)
                    return true
                end

                channel.modes[:invites].each {|invite|
                    if invite.match(client.mask)
                        return true
                    end
                }

                return false
            end

            def self.banned? (channel, client)
                channel.modes[:bans].each {|ban|
                    if ban.match(client.mask)
                        return true
                    end
                }

                return false
            end

            def self.exception? (channel, client)
                channel.modes[:exceptions].each {|exception|
                    if exception.match(client.mask)
                        return true
                    end
                }

                return false
            end
        end

        module User
            @@levels = {
                :x => '~',
                :y => '&',
                :o => '@',
                :h => '%',
                :v => '+',
            }

            def self.levels
                return @@levels
            end

            @@levelsOrder = [:x, :y, :o, :h, :v]

            def self.isLevel (char)
                @@levels.has_value?(char) ? char : false
            end

            def self.isLevelEnough (user, level)
                if !level || (level.is_a?(String) && level.empty?)
                    return true
                end

                if level.is_a?(String)
                    level = @@levels.key level
                end

                highest = self.getHighestLevel(user)

                if !highest
                    return false
                else
                    highest = @@levelsOrder.index(highest)
                    level   = @@levelsOrder.index(level)

                    if !level
                        return true
                    elsif !highest
                        return false
                    else
                        return highest <= level
                    end
                end
            end

            def self.getHighestLevel (user)
                if user.modes[:x]
                    return :x
                elsif user.modes[:y]
                    return :y
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

        # This method assigns flags recursively using groups of flags
        def self.setFlags (thing, type, value, inherited=false, forceFalse=false)
            if Base.modes[:groups][type]
                main = Base.modes[:groups]
            else
                if thing.is_a?(IRC::Server::Channel)
                    main = Base.modes[:channel]
                elsif thing.is_a?(IRC::Server::User)
                    main = Base.modes[:user]
                elsif thing.is_a?(IRC::Server::Client)
                    main = Base.modes[:client]
                else
                    raise 'What sould I do?'
                end
            end

            if !inherited
                if value == false
                    thing.modes.delete(type)
                else
                    thing.modes[type] = value
                end
            end

            if !(modes = main[type])
                return
            end

            if !modes.is_a?(Array)
                modes = [modes]
            end

            modes.each {|mode|
                if (main[mode] || Base.modes[:groups][mode]) && !thing.modes.has_key?(mode)
                    self.setFlags(thing, mode, value, !forceFalse)
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

            if !result && thing.is_a?(IRC::Server::User)
                result = thing.client.modes[type]
            end

            if result.nil?
                result = false
            end

            return result
        end

        def self.dispatchMessage (kind, from, to, message, level=nil)
            if from.is_a?(IRC::Server::User)
                from = from.client
            end

            if match = message.match(/^\x01([^ ]*)( (.*?))?\x01$/)
                from.server.execute :ctcp, :input, kind, ref{:from}, ref{:to}, match[1], match[3], level
            else
                if kind == :notice
                    from.server.execute :notice, :input, ref{:from}, ref{:to}, message, level
                elsif kind == :message
                     from.server.execute :message, :input, ref{:from}, ref{:to}, message
                end
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

        if !event.aliases.include?(:PING) && !event.aliases.include?(:PONG) && !event.aliases.include?(:WHO) && !event.aliases.include?(:MODE)
            thing.data[:last_action] = Utils::Client::Action.new(thing, event, string)
        end

        stop = false

        # if the client tries to do something without having registered, kill it with fire
        if !event.aliases.include?(:PASS) && !event.aliases.include?(:NICK) && !event.aliases.include?(:USER) && thing.class == Incoming
            thing.send :numeric, ERR_NOTREGISTERED
            stop = true
        # if the client tries to reregister, kill it with fire
        elsif (event.aliases.include?(:PASS) || event.aliases.include?(:USER)) && thing.class != Incoming
            thing.send :numeric, ERR_ALREADYREGISTRED
            stop = true
        end

        return !stop
    end

    def input_encoding (event, thing, string)
        if event.chain != :input
            return
        end

        begin
            if thing.data[:encoding]
                string.force_encoding(thing.data[:encoding])
                string.encode!('UTF-8')
            else
                string.force_encoding('UTF-8')

                if !string.valid_encoding?
                    raise Encoding::InvalidByteSequenceError
                end
            end
        rescue
            if thing.data[:encoding]
                server.execute :error, thing, 'The encoding you choose seems to not be the one you are using.'
            else
                server.execute :error, thing, 'Please specify the encoding you are using with ENCODING <encoding>'
            end

            string.force_encoding('ASCII-8BIT')

            string.encode!('UTF-8',
                :invalid => :replace,
                :undef   => :replace
            )
        end
    end

    def output_encoding (event, thing, string)
        if event.chain != :output
            return
        end

        if thing.data[:encoding]
            string.encode!(thing.data[:encoding],
                :invalid => :replace,
                :undef   => :replace
            )
        end
    end

    def unknown_command (event, thing, string)
        match = string.match(/^([^ ]+)/)

        if match && thing.class != Incoming
            thing.send :numeric, ERR_UNKNOWNCOMMAND, match[1]
        end
    end

    # This method does some checks trying to register the connection, various checks
    # for nick collisions and such.
    def registration (thing)
        if thing.class != Incoming
            return
        end

        # additional check for nick collisions
        if thing.data[:nick]
            if (thing.server.data[:nicks][thing.data[:nick]] && thing.server.data[:nicks][thing.data[:nick]] != thing) || thing.server.clients[thing.data[:nick]]
                if thing.data[:warned] != thing.data[:nick]
                    thing.send :numeric, ERR_NICKNAMEINUSE, thing.data[:nick]
                    thing.data[:warned] = thing.data[:nick]
                end

                return
            end

            thing.server.data[:nicks][thing.data[:nick]] = thing
        end

        # if the client isn't registered but has all the needed attributes, register it
        if thing.data[:user] && thing.data[:nick]
            if thing.config.attributes['password'] && thing.config.attributes['password'] != thing.data[:password]
                return false
            end

            client = thing.server.connections.things[thing.socket] = Client.new(thing)

            client.nick     = thing.data[:nick]
            client.user     = thing.data[:user]
            client.realName = thing.data[:realName]

            # clean the temporary hash value and use the nick as key
            thing.server.connections.clients[:byName][client.nick]     = client
            thing.server.connections.clients[:bySocket][client.socket] = client

            thing.server.data[:nicks].delete(client.nick)

            thing.server.execute(:registered, client)

            client.send :numeric, RPL_WELCOME, client
            client.send :numeric, RPL_HOSTEDBY, client
            client.send :numeric, RPL_SERVCREATEDON
            client.send :numeric, RPL_SERVINFO, {
                :client  => Base.supportedModes[:client].join(''),
                :channel => Base.supportedModes[:channel].join(''),
            }

            supported = String.new

            Base.support.each {|key, value|
                if value != true
                    supported << " #{key}=#{value}"
                else
                    supported << " #{key}"
                end
            }

            supported = supported[1, supported.length]

            client.send :numeric, RPL_ISUPPORT, supported

            motd(client)

            server.execute :connected, client
        end
    end

    # This method sends the MOTD 80 chars per line.
    def motd (thing)
        thing.send :numeric, RPL_MOTDSTART

        offset = 0
        motd   = @motd

        while line = motd[offset, 80]
            thing.send :numeric, RPL_MOTD, line
            offset += 80
        end

        thing.send :numeric, RPL_ENDOFMOTD
    end

    def pass (thing, string)
        if thing.class != Incoming
            return
        end

        match = string.match(/PASS\s+(:)?(.+)$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'PASS'
        else
            thing.data[:password] = match[2]

            if thing.config.attributes['password']
                if thing.data[:password] != thing.config.attributes['password']
                    server.execute(:error, thing, :close, 'Password mismatch')
                    server.kill thing, 'Password mismatch'
                    return
                end
            end

            # try to register it
            registration(thing)
        end
    end

    def nick (thing, string)
        match = string.match(/NICK\s+(:)?(.+)$/i)

        # no nickname was passed, so tell the user is a faggot
        if !match
            thing.send :numeric, ERR_NONICKNAMEGIVEN
            return
        end

        nick = match[2].strip

        if thing.class == Incoming
            if !self.check_nick(thing, nick)
                thing.data[:warned] = nick
                return
            end

            thing.data[:nick] = nick

            # try to register it
            registration(thing)
        else
            server.execute :nick, thing, nick
        end
    end

    def check_nick (thing, nick)
        if server.clients[nick] || server.data[:nicks][nick]
            thing.send :numeric, ERR_NICKNAMEINUSE, nick
            return false
        end

        allowed = eval(@nickAllowed) rescue false

        if !allowed || nick.downcase == 'anonymous'
            thing.send :numeric, ERR_ERRONEUSNICKNAME, nick
            return false
        end

        return true
    end

    def handle_nick (thing, nick)
        if !self.check_nick(thing, nick)
            return
        end

        thing.channels.each_value {|channel|
            if channel.modes[:no_nick_change] && !Utils::User::isLevelEnough(channel.user(thing), '+')
                thing.send :numeric, ERR_NONICKCHANGE, channel.name
                return false
            end
        }

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

    def user (thing, string)
        if thing.class != Incoming
            return
        end

        match = string.match(/USER\s+([^ ]+)\s+[^ ]+\s+[^ ]+\s+:(.+)$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'USER'
        else
            thing.data[:user]     = match[1]
            thing.data[:realName] = match[2]

            # try to register it
            registration(thing)
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
                    handle_mode channel.user(thing) || thing, channel, value
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

                            handle_mode thing, user, value
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

                    handle_mode thing, client, value
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

                        handle_mode thing, channel, value
                    end
                else
                    thing.send :numeric, ERR_NOSUCHCHANNEL, name
                end
            else
                if server.clients[name]
                    handle_mode thing, server.clients[name], value
                else
                    thing.send :numeric, ERR_NOSUCHNICK, name
                end
            end
        end
    end

    def handle_mode (from, thing, request, noAnswer=false)
        if match = request.match(/^=(.*)$/)
            value = match[1].strip

            if value == '?'
                server.execute :mode, :extended, from, thing, '?', nil, nil, nil
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
    
                    server.execute :mode, :extended, from, thing, type, *mode, nil
                }
            end
        else
            output = {
                :modes  => [],
                :values => [],
            }

            match = request.match(/^\s*([+\-])?\s*([^ ]+)(\s+(.+))?$/)

            if !match
                return false
            end

            type   = match[1] || '+'
            modes  = match[2].split(//)
            values = (match[4] || '').strip.split(/ /)

            modes.each {|mode|
                server.execute :mode, :normal, from, thing, type, mode, values, output
            }

            if from.is_a?(Client) || from.is_a?(User)
                from = from.mask
            end

            if !noAnswer && (!output[:modes].empty? || !output[:values].empty?)
                string = "#{type}#{output[:modes].join('')}"
                
                if !output[:values].empty?
                    string << " #{output[:values].join(' ')}"
                end

                thing.send :raw, ":#{from} MODE #{thing.is_a?(Channel) ? thing.name : thing.nick} #{string}"
            end

        end
    end

    def normal_mode (kind, from, thing, type, mode, values, output={:modes => [], :values => []})
        if kind != :normal
            return
        end

        if thing.is_a?(Channel)
            case mode

            when 'a'
                if thing.type != '&' && thing.type != '!'
                    server.execute :error, from, 'Only & and ! channels can use this mode.'
                end

                if Utils::checkFlag(from, :can_change_anonymous_mode)
                    if Utils::checkFlag(thing, :a) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :a, type == '+')

                    output[:modes].push('a')
                end

            when 'b'
                if values.empty?
                    thing.modes[:bans].each {|ban|
                        from.send :numeric, RPL_BANLIST, ban
                    }
                    
                    from.send :numeric, RPL_ENDOFBANLIST, thing.name
                    return
                end

                if Utils::checkFlag(from, :can_channel_ban)
                    mask = Mask.parse(values.shift)

                    if type == '+'
                        if !thing.modes[:bans].any? {|ban| ban == mask}
                            thing.modes[:bans].push(Utils::Channel::Modifier.new(from, thing, mask))
                        end
                    else
                        result = thing.modes[:bans].reject! {|ban|
                            if ban == mask
                                true
                            end
                        }

                        if !result
                            mask = nil
                        end
                    end

                    if mask
                        output[:modes].push('b')
                        output[:values].push(mask.to_s)
                    end
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'c'
                if Utils::checkFlag(from, :can_change_nocolors_mode)
                    if Utils::checkFlag(thing, :c) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :c, type == '+')

                    output[:modes].push('c')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'C'
                if Utils::checkFlag(from, :can_change_noctcp_mode)
                    if Utils::checkFlag(thing, :C) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :C, type == '+')

                    output[:modes].push('C')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'e'
                if values.empty?
                    thing.modes[:exceptions].each {|exception|
                        from.send :numeric, RPL_EXCEPTIONLIST, exception
                    }
                    
                    from.send :numeric, RPL_ENDOFEXCEPTIONLIST, thing.name
                    return
                end

                if Utils::checkFlag(from, :can_add_ban_exception)
                    mask = Mask.parse(values.shift)

                    if type == '+'
                        if !thing.modes[:exceptions].any? {|exception| exception == mask}
                            thing.modes[:exceptions].push(Utils::Channel::Modifier.new(from, thing, mask))
                        end
                    else
                        result = thing.modes[:exceptions].reject! {|exception|
                            if exception == mask
                                true
                            end
                        }

                        if !result
                            mask = nil
                        end
                    end

                    if mask
                        output[:modes].push('e')
                        output[:values].push(mask.to_s)
                    end
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'h'
                if Utils::checkFlag(from, :can_give_channel_half_operator)
                    value = values.shift

                    if !value || !(user = thing.users[value])
                        from.send :numeric, ERR_NOSUCHNICK, value
                        return
                    end

                    if Utils::checkFlag(user, :h) == (type == '+')
                        return
                    end

                    Utils::User::setLevel(user, :h, (type == '+'))

                    output[:modes].push('h')
                    output[:values].push(value)
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'i'
                if Utils::checkFlag(from, :can_change_invite_only_mode)
                    if Utils::checkFlag(thing, :i) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :i, type == '+')

                    output[:modes].push('i')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'I'
                if values.empty?
                    thing.modes[:invites].each {|invitation|
                        from.send :numeric, RPL_INVITELIST, invitation
                    }
                    
                    from.send :numeric, RPL_ENDOFINVITELIST, thing.name
                    return
                end

                if Utils::checkFlag(from, :can_add_invitation)
                    mask = Mask.parse(values.shift)

                    if type == '+'
                        if !thing.modes[:invites].any? {|invitation| invitation == mask}
                            thing.modes[:invites].push(Utils::Channel::Modifier.new(from, thing, mask))
                        end
                    else
                        result = thing.modes[:invites].reject! {|invitation|
                            if invitation == mask
                                true
                            end
                        }

                        if !result
                            mask = nil
                        end
                    end

                    if mask
                        output[:modes].push('I')
                        output[:values].push(mask.to_s)
                    end
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'k'
                if Utils::checkFlag(from, :can_change_channel_password)
                    value = values.shift

                    if !value
                        return
                    end

                    if type == '+' && (password = value)
                        Utils::setFlags(thing, :k, password)
                    else
                        password = thing.modes[:password]

                        Utils::setFlags(thing, :k, false)
                    end

                    if password
                        output[:modes].push('k')
                        output[:values].push(password)
                    end
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'K'
                if Utils::checkFlag(from, :can_change_noknock_mode)
                    if Utils::checkFlag(thing, :K) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :K, type == '+')

                    output[:modes].push('K')
                   
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'l'
                if Utils::checkFlag(from, :can_change_limit_mode)
                    if (!Utils::checkFlag(thing, :l) && type == '-') || (Utils::checkFlag(thing, :l) && type == '+')
                        return
                    end

                    if type == '+'
                        value = values.shift

                        if !value || !value.match(/^\d+$/)
                            return
                        end

                        Utils::setFlags(thing, :l, value.to_i)

                        output[:modes].push('l')
                        output[:values].push(value)
                    else
                        Utils::setFlags(thing, :l, false)

                        output[:modes].push('l')
                    end
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'L'
                if Utils::checkFlag(from, :can_change_redirect_mode)
                    if (!Utils::checkFlag(thing, :L) && type == '-') || (Utils::checkFlag(thing, :L) && type == '+')
                        return
                    end

                    if type == '+'
                        value = values.shift

                        if !value || !Utils::Channel::isValid(value)
                            return
                        end

                        Utils::setFlags(thing, :L, value)

                        output[:modes].push('L')
                        output[:values].push(value)
                    else
                        Utils::setFlags(thing, :L, false)

                        output[:modes].push('L')
                    end
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'm'
                if Utils::checkFlag(from, :can_change_moderated_mode)
                    if Utils::checkFlag(thing, :m) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :m, type == '+')

                    output[:modes].push('m')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'n'
                if Utils::checkFlag(from, :can_change_no_external_messages_mode)
                    if Utils::checkFlag(thing, :n) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :n, type == '+')

                    output[:modes].push('n')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'N'
                if Utils::checkFlag(from, :can_change_no_nick_change_mode)
                    if Utils::checkFlag(thing, :N) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :N, type == '+')

                    output[:modes].push('N')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'o'
                if Utils::checkFlag(from, :can_give_channel_operator)
                    value = values.shift

                    if !value || !(user = thing.users[value])
                        from.send :numeric, ERR_NOSUCHNICK, value
                        return
                    end

                    if Utils::checkFlag(user, :o) == (type == '+')
                        return
                    end

                    Utils::User::setLevel(user, :o, (type == '+'))

                    output[:modes].push('o')
                    output[:values].push(value)
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'Q'
                if Utils::checkFlag(from, :can_change_nokicks_mode)
                    if Utils::checkFlag(thing, :Q) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :Q, type == '+')

                    output[:modes].push('Q')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 's'
                if Utils::checkFlag(from, :can_change_secret_mode)
                    if Utils::checkFlag(thing, :s) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :s, type == '+')

                    output[:modes].push('s')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'S'
                if Utils::checkFlag(from, :can_change_strip_colors_mode)
                    if Utils::checkFlag(thing, :S) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :S, type == '+')

                    output[:modes].push('S')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 't'
                if Utils::checkFlag(from, :can_change_topic_mode)
                    if Utils::checkFlag(thing, :t) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :t, type == '+')

                    output[:modes].push('t')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'u'
                if Utils::checkFlag(from, :can_change_auditorium_mode)
                    if Utils::checkFlag(thing, :u) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :u, type == '+')

                    output[:modes].push('u')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'v'
                if Utils::checkFlag(from, :can_give_voice)
                    value = values.shift

                    if !value || !(user = thing.users[value])
                        from.send :numeric, ERR_NOSUCHNICK, value
                        return
                    end

                    if Utils::checkFlag(user, :v) == (type == '+')
                        return
                    end

                    Utils::User::setLevel(user, :v, (type == '+'))

                    output[:modes].push('v')
                    output[:values].push(value)
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'V'
                if Utils::checkFlag(from, :can_change_noinvites_mode)
                    if Utils::checkFlag(thing, :V) == (type == '+')
                        return
                    end

                    Utils::setFlags(thing, :V, type == '+')

                    output[:modes].push('V')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'x'
                if Utils::checkFlag(from, :can_give_channel_owner)
                    value = values.shift

                    if !value || !(user = thing.users[value])
                        from.send :numeric, ERR_NOSUCHNICK, value
                        return
                    end

                    if Utils::checkFlag(user, :x) == (type == '+')
                        return
                    end

                    Utils::User::setLevel(user, :x, (type == '+'))

                    output[:modes].push('x')
                    output[:values].push(value)
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'y'
                if Utils::checkFlag(from, :can_give_channel_admin)
                    value = values.shift

                    if !value || !(user = thing.users[value])
                        from.send :numeric, ERR_NOSUCHNICK, value
                        return
                    end

                    if Utils::checkFlag(user, :y) == (type == '+')
                        return
                    end

                    Utils::User::setLevel(user, :y, (type == '+'))

                    output[:modes].push('y')
                    output[:values].push(value)
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end

            when 'z'
                if Utils::checkFlag(from, :can_change_ssl_mode)
                    if Utils::checkFlag(thing, :z) == (type == '+')
                        return
                    end

                    if type == '+'
                        ok = true

                        thing.users.each_value {|user|
                            if !Utils::checkFlag(user, :ssl)
                                ok = false
                                break
                            end
                        }

                        if ok
                            Utils::setFlags(thing, :z, true)
                        else
                            from.send :numeric, ERR_ALLMUSTUSESSL
                            return
                        end
                    else
                        Utils::setFlags(thing, :z, false)
                    end

                    output[:modes].push('z')
                else
                    from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
                end
            end
        elsif thing.is_a?(Client)
        end
    end

    def extended_mode (kind, from, thing, type, mode, values, output=nil)
        if kind != :extended
            return
        end

        if thing.is_a?(Channel) && !Utils::checkFlag(from, :can_change_channel_extended_modes)
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
            return
        elsif thing.is_a?(User) && !Utils::checkFlag(from, :can_change_user_extended_modes)
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.channel.name
            return
        elsif thing.is_a?(Client) && from.nick != thing.nick && !Utils::checkFlag(from, :can_change_client_extended_modes) && !Utils::checkFlag(from, :frozen)
            from.send :numeric, ERR_NOPRIVILEGES
            return
        end

        if type == '?'
            if thing.is_a?(Channel)
                name = thing.name
            elsif thing.is_a?(User)
                name = "#{thing.nick}@#{thing.channel.name}"
            elsif thing.is_a?(Client)
                name = thing.nick
            end

            thing.modes[:extended].each {|key, value|
                from.server.execute :notice, :output, ref{:server}, ref{:from}, "#{name} #{key} = #{value}"
            }
        else
            if !mode.match(/^\w+$/)
                from.server.execute :error, from, "#{mode} is not a valid extended mode."
                return
            end

            if type == '+'
                thing.modes[:extended][mode.to_sym] = values || true
            else
                thing.modes[:extended].delete(mode.to_sym)
            end
        end
    end

    def encoding (thing, string)
        match = string.match(/ENCODING\s+(.+?)(\s+(.+))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'ENCODING'
            return
        end

        if match[2]
            nick = match[1].strip
            name = match[3].strip
        else
            nick = nil
            name = match[1].strip
        end

        begin
            "".encode(name)

            if nick
                if Utils::checkFlag(thing, :operator)
                    if client = server.clients[nick]
                        client.data[:encoding] = name
                    else
                        thing.send :numeric, ERR_NOSUCHNICK, nick
                    end
                else
                    thing.send :numeric, ERR_NOPRIVILEGES
                end
            else
                thing.data[:encoding] = name
            end
        rescue Encoding::ConverterNotFoundError
            server.execute(:error, thing, "#{name} is not a valid encoding.")
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
                server.execute :part, channel[thing.nick], 'Left all channels'
            }

            return
        end

        channels  = match[1].split(/,/)
        passwords = (match[3] || '').split(/,/)

        channels.each {|channel|
            channel.strip!

            if server.channels[channel] && server.channels[channel].modes[:password]
                password = passwords.shift
            else
                password = nil
            end

            server.execute :join, thing, channel, password
        }
    end

    def handle_join (thing, channel, password=nil)
        if !Utils::Channel::type(channel)
            channel = "##{channel}"
        end

        if !Utils::Channel::isValid(channel)
            thing.send :numeric, ERR_BADCHANMASK, channel
            return
        end

        @semaphore.synchronize {
            if thing.channels[channel] || @joining[thing]
                return
            end

            @joining[thing] = true

            if !server.channels[channel]
                channel = server.channels[channel] = Channel.new(server, channel)
            else
                channel = server.channels[channel]
            end
        }

        if !channel.modes[:bans]
            channel.modes[:bans]       = []
            channel.modes[:exceptions] = []
            channel.modes[:invites]    = []
            channel.modes[:invited]    = ThreadSafeHash.new
        end

        if channel.modes[:password]
            password = passwords.shift
        else
            password = ''
        end

        if channel.modes[:limit]
            if channel.users.length >= channel.modes[:limit]
                @joining.delete(thing)

                if channel.modes[:redirect]
                    join thing, "JOIN #{channel.modes[:redirect]}"
                end

                thing.send :numeric, ERR_CHANNELISFULL, channel.name

                return
            end
        end

        if channel.modes[:ssl_only] && !thing.modes[:ssl]
            thing.send :numeric, ERR_SSLREQUIRED, channel.name
            @joining.delete(thing)
            return
        end

        if channel.modes[:password] && password != channel.modes[:password]
            thing.send :numeric, ERR_BADCHANNELKEY, channel.name
            @joining.delete(thing)
            return
        end

        if channel.modes[:invite_only] && !Utils::Channel::invited?(channel, thing, true)
            thing.send :numeric, ERR_INVITEONLYCHAN, channel.name
            @joining.delete(thing)
            return
        end

        if Utils::Channel::banned?(channel, thing) && !Utils::Channel::exception?(channel, thing) && !Utils::Channel::invited?(channel, thing)
            thing.send :numeric, ERR_BANNEDFROMCHAN, channel.name
            @joining.delete(thing)
            return
        end

        server.execute(:joined, thing, channel)

        @joining.delete(thing)
    end

    def client_join (client, channel)
        empty = channel.empty?
        user  = channel.add(client)

        if empty
            handle_mode server, channel, "+o #{user.nick}", true
        else
            channel.modes[:invited].delete(client.nick)
        end

        user.client.channels.add(channel)

        if user.channel.modes[:anonymous]
            mask = Mask.new 'anonymous', 'anonymous', 'anonymous.'
        else
            mask = user.mask
        end

        user.channel.send :raw, ":#{mask} JOIN :#{user.channel}"

        if !user.channel.topic.nil?
            topic user.client, "TOPIC #{user.channel}"
        end

        self.names user.client, "NAMES #{user.channel}"
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
            server.execute :part, thing, name, message
        }
    end

    def handle_part (thing, name, message)
        if !Utils::Channel::type(name)
            name = "##{name}"
        end

        channel = server.channels[name]

        if !channel
            thing.send :numeric, ERR_NOSUCHCHANNEL, name
        elsif !thing.channels[name]
            thing.send :numeric, ERR_NOTONCHANNEL, name
        else
            server.execute(:parted, channel.user(thing), message)
        end
    end

    def user_part (user, message)
        if user.client.modes[:quitting]
            return false
        end

        text = eval(Utils::escapeMessage(@messages[:part]))

        if user.channel.modes[:anonymous]
            mask = Mask.new 'anonymous', 'anonymous', 'anonymous.'
        else
            mask = user.mask
        end

        user.channel.send :raw, ":#{mask} PART #{user.channel} :#{text}"

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

        server.execute :kick, thing, channel, user, message
    end

    def handle_kick (kicker, channel, user, message)
        if !Utils::Channel::isValid(channel)
            kicker.send :numeric, ERR_BADCHANMASK, channel
            return
        end

        if !server.channels[channel]
            kicker.send :numeric, ERR_NOSUCHCHANNEL, channel
            return
        end

        if !server.clients[user]
            kicker.send :numeric, ERR_NOSUCHNICK, user
            return
        end

        channel = server.channels[channel]
        user    = channel[user]

        if !user
            kicker.send :numeric, ERR_NOTONCHANNEL, channel.name
            return
        end

        if kicker.channels[channel.name]
            kicker = kicker.channels[channel.name].user(kicker)
        end

        if Utils::checkFlag(kicker, :can_kick)
            if channel.modes[:no_kicks]
                kicker.send :numeric, ERR_NOKICKS
            else
                server.execute(:kicked, kicker, user, message)
            end
        else
            kicker.send :numeric, ERR_CHANOPRIVSNEEDED, channel.name
        end
    end

    def send_kick (kicker, kicked, message)
        kicked.channel.send :raw, ":#{kicker.mask} KICK #{kicked.channel} #{kicked.nick} :#{message}"

        kicked.channel.delete(kicked)
        kicked.client.channels.delete(kicked.channel)
    end

    def invite (thing, string)
        match = string.match(/INVITE\s+(.+?)\s+(.+?)$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'INVITE'
            return
        end

        nick    = match[1].strip
        channel = match[2].strip

        if !server.clients[nick]
            thing.send :numeric, ERR_NOSUCHNICK, nick
            return
        end

        if server.channels[channel]
            requesting = server.channels[channel].user(thing) || thing

            if !Utils::checkFlag(requesting, :can_invite) && !thing.channels[channel]
                thing.send :numeric, ERR_NOTONCHANNEL, channel
                return
            end

            if !Utils::checkFlag(requesting, :can_invite)
                thing.send :numeric, ERR_CHANOPRIVSNEEDED, channel
                return
            end

            if server.channels[channel].users[nick]
                thing.send :numeric, ERR_USERONCHANNEL, {
                    :nick    => nick,
                    :channel => channel,
                }

                return
            end

            if server.channels[channel].modes[:no_invites]
                thing.send :numeric, ERR_NOINVITE, channel
                return false
            end
        end

        client = server.clients[nick]

        if client.modes[:away]
            thing.send :numeric, RPL_AWAY, client
        end

        server.execute :invite, thing, client, channel
    end

    def client_invite (from, to, channel)
        from.send :numeric, RPL_INVITING, {
            :nick    => to.nick,
            :channel => channel,
        }

        target = channel

        if channel = server.channels[target]
            channel.modes[:invited][to.nick] = true
            server.execute :notice, :input, ref{:server}, ref{:channel}, "#{from.nick} invited #{to.nick} into the channel.", '@'
        end

        to.send :raw, ":#{from.mask} INVITE #{to.nick} :#{target}"
    end

    def knock (thing, string)
        match = string.match(/KNOCK\s+(.+?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'KNOCK'
            return
        end

        channel = match[1]
        message = match[3]

        if !server.channels[channel]
            thing.send :numeric, ERR_NOKNOCK, { :channel => channel, :reason => 'Channel does not exist!' }
            return
        end

        channel = server.channels[channel]

        if !channel.modes[:invite_only]
            thing.send :numeric, ERR_NOKNOCK, { :channel => channel.name, :reason => 'Channel is not invite only!' }
            return
        end

        if channel.modes[:no_knock]
            thing.send :numeric, ERR_NOKNOCK, { :channel => channel.name, :reason => 'No knocks are allowed! (+K)' }
            return
        end

        server.execute :notice, :input, ref{:server}, ref{:channel}, "[Knock] by #{thing.mask} (#{message ? message : 'no reason specified'})", '@'
        server.execute :notice, :input, ref{:server}, ref{:thing}, "Knocked on #{channel.name}"
    end

    def topic (thing, string)
        match = string.match(/TOPIC\s+(.*?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'TOPIC'
            return
        end

        channel = match[1].strip

        if !server.channels[channel]
            thing.send :numeric, ERR_NOSUCHCHANNEL, channel
            return
        end

        channel = server.channels[channel]

        if !Utils::checkFlag(thing, :can_change_topic) && !thing.channels[channel.name] && !Utils::checkFlag(thing, :operator)
            thing.send :numeric, ERR_NOTONCHANNEL, channel
        else
            if match[2]
                topic = match[3].to_s

                if channel.modes[:t] && !Utils::checkFlag(channel.user(thing), :can_change_topic)
                    thing.send :numeric, ERR_CHANOPRIVSNEEDED, channel
                else
                    server.execute :topic_change, channel, topic, ref{:thing}
                end
            else
                if !channel.topic
                    thing.send :numeric, RPL_NOTOPIC, channel
                else
                    thing.send :numeric, RPL_TOPIC, channel.topic
                    thing.send :numeric, RPL_TOPICSETON, channel.topic
                end
            end
        end
    end

    def topic_change (channel, topic, fromRef)
        channel.topic = [fromRef.value, topic]

        channel.send :raw, ":#{channel.topic.setBy} TOPIC #{channel} :#{channel.topic}"
    end

    def names (thing, string)
        match = string.match(/NAMES\s+(.*)$/i)

        if !match
            thing.send :numeric, RPL_ENDOFNAMES, thing.nick
            return
        end

        channel = match[1].strip

        if channel = thing.channels[channel]
            users = String.new
            thing = channel.user(thing)

            channel.users.each_value {|user|
                if channel.modes[:auditorium] && !Utils::User::isLevelEnough(user, '%') && !Utils::checkFlag(thing, :operator)
                    if user.modes[:level]
                        users << " #{user}"
                    end
                else
                    users << " #{user}"
                end
            }

            users = users[1, users.length]

            thing.send :numeric, RPL_NAMREPLY, {
                :channel => channel.name,
                :users   => users,
            }
        end

        thing.send :numeric, RPL_ENDOFNAMES, channel
    end

    def list (thing, string)
        match = string.match(/LIST(\s+(.*))?$/)

        channels = (match[2] || '').strip.split(/,/)

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
            thing.server.execute(:whois, thing, name)
        }
    end

    def handle_whois (thing, name)
        if !server.clients[name]
            thing.send :numeric, ERR_NOSUCHNICK, name
            return
        end

        client = server.clients[name]

        thing.send :numeric, RPL_WHOISUSER, client

        if thing.modes[:operator]
            thing.send :numeric, RPL_WHOISMODES, client
            thing.send :numeric, RPL_WHOISCONNECTING, client
        end

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
            thing.send :numeric, RPL_AWAY, client
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

    def ison (thing, string)
        match = string.match(/ISON\s+(.+)$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'ISON'
            return
        end

        result = String.new

        match.split(/\s+/).each {|nick|
            if server.clients[nick]
                result << " #{nick}"
            end
        }

        result = result[1, result.length]

        thing.send :numeric, RPL_ISON, result
    end

    def privmsg (thing, string)
        match = string.match(/PRIVMSG\s+(.*?)(\s+:(.*))?$/i)

        if !match
            thing.send :numeric, ERR_NORECIPIENT, 'PRIVMSG'
            return
        end

        if !match[3]
            thing.send :numeric, ERR_NOTEXTTOSEND
            return
        end

        receiver = match[1]
        message  = match[3]

        if Utils::Channel::isValid(receiver)
            channel = server.channels[receiver]

            if !channel
                thing.send :numeric, ERR_NOSUCHNICK, receiver
                return
            end

            thing = channel.user(thing) || thing

            if channel.modes[:moderated] && !Utils::checkFlag(thing, :can_talk)
                thing.send :numeric, ERR_YOUNEEDVOICE, channel.name
                return
            end

            if Utils::Channel::banned?(channel, thing) && !Utils::Channel::exception?(channel, thing)
                thing.send :numeric, ERR_YOUAREBANNED, channel.name
                return
            end

            if thing.is_a?(User)
                Utils::dispatchMessage(:message, thing, channel, message)
            else
                if server.channels[receiver].modes[:no_external_messages]
                    thing.send :numeric, ERR_NOEXTERNALMESSAGES, channel.name
                else
                    Utils::dispatchMessage(:message, thing, channel, message)
                end
            end
        else
            client = server.clients[receiver]

            if !client
                thing.send :numeric, ERR_NOSUCHNICK, receiver
            else
                Utils::dispatchMessage(:message, thing, client, message)
            end
        end
    end

    def handling_message (chain, fromRef, toRef, message)
        if chain != :input
            return
        end

        from = fromRef.value
        to   = toRef.value

        if to.is_a?(Channel)
            if to.modes[:strip_colors]
                message.gsub!(/\x03((\d{1,2})?(,\d{1,2})?)?/, '')
            end

            if to.modes[:no_colors] && message.include?("\x03")
                from.send :numeric, ERR_NOCOLORS, to.name
                return false
            end

            to.users.each_value {|user|
                if user.client != from
                    server.execute :message, :output, fromRef, ref{:user}, message
                end
            }
        elsif to.is_a?(Client)
            server.execute :message, :output, fromRef, toRef, message
        end
    end

    def send_message (chain, fromRef, toRef, message)
        if chain != :output
            return
        end

        from = fromRef.value
        to   = toRef.value

        if to.is_a?(User)
            name = to.channel.name

            if to.channel.modes[:anonymous]
                from = Mask.new 'anonymous', 'anonymous', 'anonymous.'
            end
        elsif to.is_a?(Client)
            name = to.nick
        else
            return
        end

        to.send :raw, ":#{from} PRIVMSG #{name} :#{message}"
    end

    def notice (thing, string)
        match = string.match(/NOTICE\s+(.*?)\s+:(.*)$/i)

        if !match
            return
        end

        name    = match[1]
        message = match[2]

        if client = server.clients[name]
            Utils::dispatchMessage(:notice, thing, client, message)
        else
            if Utils::User::isLevel(name[0, 1])
                level   = name[0, 1]
                channel = name[1, name.length]
            else
                level   = nil
                channel = name
            end

            if !server.channels[channel]
                # unrealircd sends an error if it can't find nick/channel, what should I do?
                return
            end

            channel = server.channels[channel]

            if !channel.modes[:no_external_messages] || channel.user(thing)
                Utils::dispatchMessage(:notice, thing, channel, message, level)
            end
        end
    end

    def handling_notice (chain, fromRef, toRef, message, level=nil)
        if chain != :input
            return
        end

        from = fromRef.value
        to   = toRef.value

        if to.is_a?(Channel)
            to.users.each_value {|user|
                if user.client != from && Utils::User::isLevelEnough(user, level)
                    server.execute :notice, :output, fromRef, ref{:user}, message, level
                end
            }
        elsif to.is_a?(Client)
            server.execute :notice, :output, fromRef, toRef, message, level
        end
    end

    def send_notice (chain, fromRef, toRef, message, level=nil)
        if chain != :output
            return
        end

        from = fromRef.value
        to   = toRef.value

        if to.is_a?(User)
            name = to.channel.name

            if to.channel.modes[:anonymous]
                from = Mask.new 'anonymous', 'anonymous', 'anonymous.'
            end
        elsif to.is_a?(Client)
            name = to.nick
        else
            return
        end

        to.send :raw, ":#{from} NOTICE #{level}#{name} :#{message}"
    end

    def handling_ctcp (chain, kind, fromRef, toRef, type, message, level=nil)
        if chain != :input
            return
        end

        from = fromRef.value
        to   = toRef.value

        if to.is_a?(Channel)
            if to.modes[:no_ctcps]
                from.send :numeric, ERR_NOCTCPS, to.name
                return false
            end

            to.users.each_value {|user|
                if user.client != from && Utils::User::isLevelEnough(user, level)
                    server.execute :ctcp, :output, kind, fromRef, ref{:user}, type, message, level
                end
            }
        elsif to.is_a?(Client) || to.is_a?(User)
            server.execute :ctcp, :output, kind, fromRef, toRef, type, message, level
        end
    end

    def send_ctcp (chain, kind, fromRef, toRef, type, message, level=nil)
        if chain != :output
            return
        end

        from = fromRef.value
        to   = toRef.value

        if to.is_a?(User)
            name = to.channel.name

            if to.channel.modes[:anonymous]
                from = Mask.new 'anonymous', 'anonymous', 'anonymous.'
            end
        elsif to.is_a?(Client)
            name = to.nick
        else
            return
        end

        if message
            text = "#{type} #{message}"
        else
            text = type
        end

        if kind == :message
            kind  = 'PRIVMSG'
            level = ''
        elsif kind == :notice
            kind = 'NOTICE'
        end

        if kind.is_a?(String)
            to.send :raw, ":#{from} #{kind} #{level}#{name} :\x01#{text}\x01"
        end
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
        server.execute :notice, :input, ref{:server}, ref{:thing}, 'The X tells the point.'
    end

    def version (thing, string)
        comments = eval(Utils::escapeMessage(@messages[:version]))

        thing.send :numeric, RPL_VERSION, comments
    end

    def oper (thing, string)
        match = string.match(/OPER\s+(.*?)(\s+(.*?))?$/i)

        if !match
            thing.send :numeric, ERR_NEEDMOREPARAMS, 'OPER'
            return
        end

        password = match[3] || match[1]
        name     = (match[3]) ? match[1] : nil

        mask = thing.mask.clone

        if name
            mask.nick = name
        end

        server.config.elements['config/operators'].elements.each('operator') {|element|
            if mask.match(element.attributes['mask']) && password == element.attributes['password']
                element.attributes['flags'].split(/,/).each {|flag|
                    Utils::setFlags(thing, flag.to_sym, true, false, true)
                }

                thing.modes[:message] = 'is an IRC operator'

                thing.send :numeric, RPL_YOUREOPER
                thing.send :raw, ":#{server} MODE #{thing.nick} #{thing.modes}"

                thing.server.execute :oper, true, thing, name, password
                return
            end
        }

        thing.send :numeric, ERR_NOOPERHOST
        thing.server.execute :oper, false, thing, name, password
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
        if !thing.is_a?(Client)
            return
        end

        server.data[:nicks].delete(thing.nick)

        @toPing.delete(thing.socket)
        @pingedOut.delete(thing.socket)

        thing.channels.select {|name, channel| channel.modes[:anonymous]}.each_value {|channel|
            server.execute :part, channel.user(thing).clone, message
        }

        thing.channels.unique_users.send :raw, ":#{thing.mask} QUIT :#{message}"
    end 
end

end

end

end
