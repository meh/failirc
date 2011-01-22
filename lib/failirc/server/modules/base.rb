#--
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
#++

require 'forwardable'

require 'failirc/modes'
require 'failirc/mask'
require 'failirc/errors'
require 'failirc/responses'

module IRC; class Server

Module.define('base', '0.0.1') {
  module Flags
    Groups = {
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
        :can_change_noinvites_mode, :can_change_private_mode,
      ],
  
      :can_change_user_modes => [
        :can_give_channel_operator, :can_give_channel_half_operator,
        :can_give_voice, :can_change_user_extended_modes,
      ],
  
      :can_change_client_modes => [
        :can_change_client_extended_modes,
      ]
    }
  
    def set_flags (type, value, inherited=false, force=false)
      if !inherited
        if value == false
          self.modes.delete(type)
        else
          self.modes[type] = value
        end
      end
  
      return unless modes = (Modes[type] || Groups[type])
      
      if !modes.is_a?(Array)
        modes = [modes]
      end
  
      modes.each {|mode|
        if (Modes[mode] || Groups[mode]) && !self.modes.has_key?(mode)
          set_flags mode, value, !force
        else
          if value == false
            if !Modes.has_key?(mode)
              self.modes.delete(mode)
            end
          else
            self.modes[mode] = value
          end
        end
      }
    end
  
    def has_flag? (type)
      self.modes[type] || self.modes[:extended][type] || false
    end
  end
  
  class Server < Incoming
    include Flags

    Modes = {}
  
    attr_reader :server, :servers, :socket, :listen, :host

    def initialize (server, socket, listen)
      super(server, socket, listen)

      @servers = {}
    end

    def has_flag? (type)
      true
    end

    def identifier
      host
    end

    def to_s
      host
    end

    def inspect
      "#{host}[#{ip}/#{port}]"
    end
  end

  class Client < Incoming
    extend  Forwardable
    include Flags

    Modes = {
      :z => :ssl,
  
      :N => [:o, :netadmin],
      :o => [:operator, :can_kill, :can_kick, :can_see_secrets, :can_give_channel_owner, :can_give_channel_admin, :can_change_channel_modes, :can_change_user_modes, :can_change_client_modes],

      :netadmin => :N,
      :operator => :o,
    }

    attr_reader    :channels, :mask, :connected_on
    attr_accessor  :password, :real_name, :modes  
    def_delegators :@mask, :nick, :nick=, :user, :user=, :host, :host=
 
    def initialize (server, socket=nil, options=nil)
      super(server, socket, options)
  
      @registered = false
  
      @channels = Channels.new(@server)
      @modes    = IRC::Modes.new
  
      if socket.is_a?(Mask)
        @mask = socket
      else
        @mask     = Mask.new
        self.host = @socket.peeraddr[2]
  
        if @socket.is_a?(OpenSSL::SSL::SSLSocket)
          @modes[:ssl] = @modes[:z] = true
        end
      end
  
      @connected_on = Time.now
    end

    def identifier
      nick
    end
  
    def to_s
      mask.to_s
    end
  
    def inspect
      "#{mask}[#{ip}/#{port}]"
    end
  end

  class Clients < Hash
    attr_reader :server
  
    def initialize (server, *args)
      @server = server
  
      super(*args)
    end
  
    def send (*args)
      each_value {|client|
        client.send(*args)
      }
    end
  
    def inspect
      map {|(_, client)|
        client.inspect
      }.join(' ')
    end
  end
  
  class User
    extend  Forwardable
    include Flags
  
    Modes = {
      :! => [:x],
      :x => [:y, :can_give_channel_admin],
      :y => [:o, :admin],
      :o => [:h, :operator, :can_change_topic, :can_invite, :can_change_channel_modes, :can_change_user_modes],
      :h => [:v, :halfoperator, :can_kick],
      :v => [:voice, :can_talk]
    }

    Levels = {
      :! => '!',
      :x => '~',
      :y => '&',
      :o => '@',
      :h => '%',
      :v => '+'
    }
  
    attr_reader    :client, :channel, :modes
    def_delegators :@client, :mask, :server, :data, :nick, :user, :host, :real_name, :send
  
    def initialize (client, channel, modes=IRC::Modes.new)
      @client  = client
      @channel = channel
      @modes   = modes
    end
  
    alias __has_flag? has_flag?
  
    def has_flag? (type, limited=false)
      result = __has_flag?(type)
  
      if !result && !limited
        result = self.client.has_flag?(type)
      end
  
      result
    end
  
    def is_level_enough? (level)
      return true if !level || (level.is_a?(String) && level.empty?)
  
      if level.is_a?(String)
        level = Levels.key level
      end
  
      highest = self.getHighestLevel(user)
  
      return false unless highest
  
      highest = Levels.keys.index(highest)
      level   = Levels.keys.index(level)
  
      if !level
        return true
      elsif !highest
        return false
      else
        return highest <= level
      end
    end
  
    def highest_level
      Levels.each_key {|level|
        if modes[level]
          return level
        end
      }
    end
  
    def set_level (level, value)
      if Levels[level]
        set_flags level, value
  
        if value
          modes[:level] = Levels[level]
        else
          set_level highest_level, true
        end
      else
        modes[:level] = ''
      end
    end

    def to_s
      return "#{modes[:level]}#{nick}"
    end
  
    def inspect
      return "#<User: #{client.inspect} #{channel.inspect} #{modes.inspect}>"
    end
  end

  class Users < ThreadSafeHash
    extend Forwardable

    attr_reader    :channel
    def_delegators :@channel, :server
  
    def initialize (channel, *args)
      @channel = channel
  
      super(*args)
    end
  
    alias __get [] 
    alias __set []=
    alias __delete delete
  
    def [] (user)
      if user.is_a?(Client) || user.is_a?(User)
        user = user.nick
      end
  
      __get(user)
    end
  
    def []= (user, value)
      if user.is_a?(Client) || user.is_a?(User)
        user = user.nick
      end
  
      __set(user, value)
    end
    
    def delete (key)
      if key.is_a?(User) || key.is_a?(Client)
        key = key.nick
      end
  
      key = key.downcase
      user = self[key]
  
      if user
        __delete(key)
      end
  
      return user
    end
  
    def add (user)
      case user
        when Client then self[user.nick] = User.new(user, @channel)
        when User   then self[user.nick] = user
      end
    end
  
    def send (*args)
      each_value {|user|
        user.send(*args)
      }
    end
  end
  
  class Channel
    extend  Forwardable
    include Flags

    class Topic
      attr_reader :server, :channel, :text, :set_by
      attr_accessor :set_on
  
      def initialize (channel)
        @server  = channel.server
        @channel = channel
  
        @semaphore = Mutex.new
      end
  
      def text= (value)
        @semaphore.synchronize {
          @text  = value
          @setOn = Time.now
        }
      end
  
      def set_by= (value)
        if value.is_a?(Mask)
          @set_by = value
        else
          @set_by = value.mask.clone
        end
      end
  
      def to_s
        text
      end
  
      def nil?
        text.nil?
      end
    end
  
    Modes = {
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
      :p => :private,
      :Q => :no_kicks,
      :s => :secret,
      :S => :strip_colors,
      :t => :topic_lock,
      :u => :auditorium,
      :V => :no_invites,
      :z => :ssl_only,
    }

    attr_reader    :server, :name, :type, :created_on, :modes, :topic 
    attr_writer    :level
    def_delegators :@users, :[], :add, :delete, :empty?
  
    def initialize (server, name)
      raise ArgumentError.new('It is not a valid channel name') unless name.is_valid_channel?

      @server = server
      @name   = name
      @type   = name[0, 1]
  
      @created_on = Time.now
      @users      = Users.new(self)
      @modes      = IRC::Modes.new
      @topic      = Topic.new(self)
    end
  
    def type
      @name[0, 1]
    end
  
    def topic= (data)
      if data.is_a?(Topic)
        @topic.set_by = data.set_by
        @topic.text   = data.text
      elsif data.is_a?(Array)
        @topic.set_by = data[0]
        @topic.text  = data[1]
      end
    end

    def users
      if @level
        Users.new(self, @users.select {|user|
          user.is_level_enough?(@level)
        })
      else
        @users
      end
    end
  
    def user (client)
      return @users[client.nick]
    end

    def send (*args)
      users.send(*args)
    end

    def banned? (client)
      modes[:bans].each {|ban|
        return true if ban.match(client.mask)
      }

      return false
    end

    def exception? (client)
      modes[:exceptions].each {|exception|
        return true if exception.match(client.mask)
      }

      return false
    end

    def invited? (client, shallow=false)
      return true if shallow && !channel.modes[:invite_only]

      return true if channel.modes[:invited][client.mask]

      modes[:invites].each {|invite|
        return true if invite.match(client.mask)
      }

      return false
    end
  
    def to_s
      @name
    end

    def level?
      @level
    end

    def level (level)
      return self unless level

      result       = self.clone
      result.level = level
    end
  end

  class Channels < ThreadSafeHash
    attr_reader :server
  
    def initialize (server, *args)
      @server = server
  
      super(*args)
    end
  
    alias __delete delete
  
    def delete (channel)
      if channel.is_a?(Channel)
        __delete(channel.name)
      else
        __delete(channel)
      end
    end
  
    def add (channel)
      self[channel.name] = channel
    end
  
    # get single users in the channels
    def unique_users
      result = Clients.new(server)
  
      each_value {|channel|
        channel.users.each {|nick, user|
          result[nick] = user.client
        }
      }
  
      return result
    end
  
    def to_s (thing=nil)
      map {|(_, channel)|
        if thing.is_a?(Client) || thing.is_a?(User)
          "#{channel.user(thing).modes[:level]}#{channel.name}"
        else
          "#{channel.name}"
        end
      }.join(' ')
    end
  end
  
  class ::String
    def is_level?
      User::Levels.has_value?(self) ? self : false
    end

    def is_valid_channel?
      !!self.to_s.match(/^[&#+!][^ ,:\a]{0,50}$/)
    end

    def channel_type
      self[0] if self.is_valid_channel?
    end
  end

  class Action
    attr_reader :client, :event, :string, :on

    def initialize (client, event, string)
      @client = client
      @event  = event
      @string = string
      @on   = Time.now
    end
  end

  on start do |server|
    @supported_modes = {
      :client  => 'Nzo',
      :channel => 'abcCehiIkKlLmnNoQsStuvVxyz'
    }

    @support ={ 
      :CASEMAPPING => 'ascii',
      :SAFELIST    => true,
      :EXCEPTS     => 'e',
      :INVEX       => 'I',
      :CHANTYPES   => '&#+!',
      :CHANMODES   => 'beI,kfL,lj,acCiKmnNQsStuVz',
      :PREFIX      => '(!xyohv)!~&@%+',
      :STATUSMSG   => '~&@%+',
      :FNC         => true,

      :CMDS => 'KNOCK'
    }

    @semaphore  = Mutex.new
    @joining    = {}
    @pinged_out = {}
    @to_ping    = {}
    @nicks      = []
    @channels   = Channels.new(server)
    @clients    = {}
    @servers    = {}

    Thread.new {
      while server.running?
        @semaphore.synchronize {
          # time to ping non active users
          @to_ping.each_value {|thing|
            @pinged_out[thing.socket] = thing

            if thing.class != Incoming
              thing.send :raw, "PING :#{server.host}"
            end
          }

          # clear and refill the hash of clients to ping with all the connected clients
          @to_ping.clear
          @to_ping.merge!(server.connections.things)
        }

        sleep((options[:misc]['ping timeout'].to_f rescue 60))

        @semaphore.synchronize {
          # people who didn't answer with a PONG have to YIFF IN HELL.
          @pinged_out.each_value {|thing|
            if !thing.socket.closed?
              server.kill thing, 'Ping timeout', true
            end
          }

          @pinged_out.clear
        }
      end
    }
  end

  on connection do |thing|
    thing.data.encoding = 'UTF-8'
  end

  on killed do |thing, message|
    case thing
      when Client
        thing.channels.each_value {|channel|
          channel.users.delete(thing.nick)

          if channel.empty?
            @channels.delete(channel.name)
          end
        }

        @nicks.delete(thing.nick)
        
      when Server

      when Incoming
        @nicks.delete(thing.data.nick)
    end
  end

  def check_encoding (string)
    result   = false
    encoding = string.encoding

    ['UTF-8', 'ISO-8859-1'].each {|encoding|
      string.force_encoding(encoding)

      if string.valid_encoding?
        result = encoding
      end
    }

    string.force_encoding(encoding)

    return result
  end

  # check encoding
  input do before -123456789 do |event, thing, string|
    begin
      string.force_encoding(thing.data.encoding)

      if !string.valid_encoding?
        if !thing.data.encoding_tested && (tmp = check_encoding(string))
          thing.data.encoding_tested = true
          thing.data.encoding        = tmp

          string.force_encoding(tmp)
        else
          raise Encoding::InvalidByteSequenceError
        end
      end

      string.encode!('UTF-8')
    rescue
      if thing.data.encoding
        server.fire :error, thing, 'The encoding you choose seems to not be the one you are using.'
      else
        server.fire :error, thing, 'Please specify the encoding you are using with ENCODING <encoding>'
      end

      string.force_encoding('ASCII-8BIT')

      string.encode!('UTF-8',
        :invalid => :replace,
        :undef   => :replace
      )
    end
  end end

  output do after 123456789 do |event, thing, string|
    if thing.data.encoding
      string.encode!(thing.data.encoding,
        :invalid => :replace,
        :undef   => :replace
      )
    end
  end end

  input {
    aliases {
      pass /^PASS( |$)/i
      nick /^(:[^ ]\s+)?NICK( |$)/i
      user /^(:[^ ]\s+)?USER( |$)/i

      motd /^MOTD( |$)/i

      ping /^PING( |$)/i
      pong /^PONG( |$)/i

      away     /^AWAY( |$)/i
      mode     /^MODE( |$)/i
      encoding /^ENCODING( |$)/i

      join   /^(:[^ ] )?JOIN( |$)/i
      part   /^(:[^ ] )?PART( |$)/i
      kick   /^(:[^ ] )?KICK( |$)/i
      invite /^INVITE( |$)/i
      knock  /^KNOCK( |$)/i

      topic /^(:[^ ] )?TOPIC( |$)/i
      names /^NAMES( |$)/i
      list  /^LIST( |$)/i

      who    /^WHO( |$)/i
      whois  /^WHOIS( |$)/i
      whowas /^WHOWAS( |$)/i
      ison   /^ISON( |$)/i

      privmsg /^(:[^ ] )?PRIVMSG( |$)/i
      notice  /^NOTICE( |$)/i

      map     /^MAP( |$)/i
      version /^VERSION( |$)/i

      oper   /^OPER( |$)/i
      kill   /^KILL( |$)/i
      rehash /^REHASH( |$)/i

      quit /^QUIT( |$)/i
    }

    # check for ping timeout and registration
    before -123456789 do |event, thing, string|
      @semaphore.synchronize {
        @to_ping.delete(thing.socket)
        @pinged_out.delete(thing.socket)
      }

      if !event.alias?(:PING) && !event.alias?(:PONG) && !event.alias?(:WHO) && !event.alias?(:MODE)
        thing.data.last_action = Action.new(thing, event, string)
      end
  
      # if the client tries to do something without having registered, kill it with fire
      if !event.alias?(:PASS) && !event.alias?(:NICK) && !event.alias?(:USER) && thing.class == Incoming
        thing.send :numeric, ERR_NOTREGISTERED

        throw :halt
      # if the client tries to reregister, kill it with fire
      elsif (event.alias?(:PASS) || event.alias?(:USER)) && thing.class != Incoming
        thing.send :numeric, ERR_ALREADYREGISTRED

        throw :halt
      end
    end

    fallback do |event, thing, string|
      whole, command = string.match(/^([^ ]+)/).to_a

      thing.send :numeric, ERR_UNKNOWNCOMMAND, command
    end

    observe :error do |thing, message, type=nil|
      thing.send :raw, case type
        when :close; "Closing Link: #{thing.nick}[#{thing.ip}] (#{message})"
        else;        "ERROR :#{message}"
      end
    end

    def motd (thing, string=nil)
      thing.send :numeric, RPL_MOTDSTART
  
      options[:misc][:motd].interpolate(binding).split(/\n/).each {|line|
        offset = 0
  
        while part = line[offset, 80]
          if (tmp = line[offset + 80, 1]) && !tmp.match(/\s/)
            part.sub!(/([^ ]+)$/, '')
  
            if (tmp = part.length) == 0
              tmp = 80
            end
          else
            tmp = 80
          end
  
          offset += tmp
  
          if part.strip.length == 0 && line.strip.length > 0
            next
          end
  
          thing.send :numeric, RPL_MOTD, part.strip
        end
      }
  
      thing.send :numeric, RPL_ENDOFMOTD
    end

    # This method does some checks trying to register the connection, various checks
    # for nick collisions and such.
    def register (thing)
      return if thing.class != Incoming

      # if the client isn't registered but has all the needed attributes, register it
      if thing.data.user && thing.data.nick
        if thing.options['password'] && thing.options['password'] != thing.data.password
          return false
        end
  
        client           = Client.new(thing)
        client.nick      = thing.data.nick
        client.user      = thing.data.user
        client.real_name = thing.data.real_name
  
        @clients[client.nick] = (server.connections << client)
  
        server.fire(:registered, client)

        client.send :numeric, RPL_WELCOME, client
        client.send :numeric, RPL_HOSTEDBY, client
        client.send :numeric, RPL_SERVCREATEDON
        client.send :numeric, RPL_SERVINFO, {
          :client  => @supported_modes[:client],
          :channel => @supported_modes[:channel],
        }
  
        client.send :numeric, RPL_ISUPPORT, @support.map {|(key, value)|
          if value != true
            "#{key}=#{value}"
          else
            "#{key}"
          end
        }.join(' ')

        if !client.modes.to_s.empty?
          client.send :raw, ":#{server} MODE #{client.nick} #{client.modes}"
        end
  
        motd(client)
  
        server.fire :connected, client
      end
    end
  
    on pass do |thing, string|
      return if thing.class != Incoming
  
      whole, password = string.match(/PASS\s+(?::)?(.*)$/i).to_a
  
      if !password
        thing.send :numeric, ERR_NEEDMOREPARAMS, :PASS
        return
      end
  
      thing.data.password = password
  
      if thing.options[:password]
        if thing.data.password != thing.options[:password]
          server.fire :error, thing, :close, 'Password mismatch'
          server.kill thing, 'Password mismatch'
          return
        end
      end
  
      # try to register it
      register(thing)
    end

    on nick do |thing, string|
      whole, from, nick = string.match(/^(?::(.+?)\s+)?NICK\s+(?::)?(.+)$/i).to_a

      # no nickname was passed, so tell the user is a faggot
      if !nick
        thing.send :numeric, ERR_NONICKNAMEGIVEN
        return
      end
  
      @semaphore.synchronize {
        case thing 
          when Client
            server.fire :nick, thing, nick
    
          when Server
    
          when Incoming
            if !nick_is_ok?(thing, nick)
              thing.data.warned = nick
              return
            end

            @nicks.delete(thing.data.nick)
            @nicks << (thing.data.nick = nick)
    
            # try to register it
            register(thing)
        end
      }
    end

    observe :nick do |thing, nick|
      @semaphore.synchronize {  
        return unless nick_is_ok?(thing, nick)
  
        thing.channels.each_value {|channel|
          if channel.modes[:no_nick_change] && !channel.user(thing).is_level_enough?('+')
            thing.send :numeric, ERR_NONICKCHANGE, channel.name
            return
          end
        }

        @nicks.delete(thing.nick)
        @nick << nick

        mask       = thing.mask.clone
        thing.nick = nick
  
        @clients[thing.nick] = @clients.delete(mask.nick)
  
        thing.channels.each_value {|channel|
          channel.users.add(channel.users.delete(mask.nick))
        }
  
        if thing.channels.empty?
          thing.send :raw, ":#{mask} NICK :#{nick}"
        else
          thing.channels.unique_users.send :raw, ":#{mask} NICK :#{nick}"
        end
      }
    end

    def nick_is_ok? (thing, nick)
      if thing.is_a?(Client)
        if thing.nick == nick
          return false
        end
  
        if thing.nick.downcase == nick.downcase
          return true
        end
      end
  
      if @nicks.member?(nick)
        thing.send :numeric, ERR_NICKNAMEINUSE, nick
        return false
      end
  
      if !(eval(options[:misc]['allowed nick']) rescue false) || nick.downcase == 'anonymous'
        thing.send :numeric, ERR_ERRONEUSNICKNAME, nick
        return false
      end
  
      return true
    end

    on user do |thing, string|
      return if thing.class != Incoming

      whole, user, real_name = string.match(/USER\s+([^ ]+)\s+[^ ]+\s+[^ ]+\s+:(.*)$/i).to_a
  
      if !real_name
        thing.send :numeric, ERR_NEEDMOREPARAMS, :USER
      else
        thing.data.user      = user
        thing.data.real_name = realname
  
        # try to register it
        register(thing)
      end
    end

    on :motd, &method(:motd)

    on ping do |thing, string|
      whole, what = string.match(/PING\s+(.*)$/i).to_a

      if !whole
        thing.send :numeric, ERR_NOORIGIN
        return
      end

      thing.send :raw, ":#{server.host} PONG #{server.host} :#{what}"
    end

    on pong do |thing, string|
      whole, what = string.match(/PONG\s+(?::)?(.*)$/i).to_a

      if !whole
        thing.send :numeric, ERR_NOORIGIN
        return
      end

      if what != server.host
        thing.send :numeric, ERR_NOSUCHSERVER, what
      end
    end

    on away do |thing, string|
      whole, message = string.match(/AWAY\s+(?::)(.*)$/i).to_a

      if !whole || message.empty?
        thing.data.away = false
        thing.send :numeric, RPL_UNAWAY
      else
        thing.data.away = message
        thing.send :numeric, RPL_NOWAWAY
      end
    end

    # MODE user/channel = +option,-option
    on mode do |thing, string|
      whole, name, value = string.match(/MODE\s+([^ ]+)(?:\s+(?::)?(.*))?$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, :MODE
        return
      end
  
      # long options, extended protocol
      if value && value.match(/^=\s+(.*)$/)
        if name.is_valid_channel?
          if channel = server.channels[name]
            server.fire :mode, channel.user(thing) || thing, channel, value
          else
            thing.send :numeric, ERR_NOSUCHCHANNEL, name
          end
        elsif match = name.match(/^([^@])@(.*)$/)
          user    = match[1]
          channel = match[2]
  
          if tmp = @channels[channel]
            channel = tmp
  
            if tmp = @clients[user]
              if tmp = channel.user(tmp)
                server.fire :mode, thing, tmp, value
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
          if client = @clients[name]
            server.fire :mode, thing, client, value
          else
            thing.send :numeric, ERR_NOSUCHNICK, name
          end
        end
      # usual shit
      else
        if name.is_valid_channel?
          if channel = @channels[name]
            if !value || value.empty?
              thing.send :numeric, RPL_CHANNELMODEIS, channel
              thing.send :numeric, RPL_CHANCREATEDON, channel
            else
              if thing.channels[name]
                thing = thing.channels[name].user(thing)
              end
  
              server.fire :mode, thing, channel, value
            end
          else
            thing.send :numeric, ERR_NOSUCHCHANNEL, name
          end
        else
          if client = @clients[name]
            server.fire :mode, thing, client, value
          else
            thing.send :numeric, ERR_NOSUCHNICK, name
          end
        end
      end
    end

    observe :mode do |from, thing, request, answer=true|

    end

    on encoding do |thing, string|
      whole, encoding, nick = string.match(/ENCODING\s+(.+?)(?:\s+(.+))?$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, :ENCODING
        return
      end
  
      if !Encoding.name_list.include?(encoding)
        server.fire :error, thing, "#{encoding} is not a valid encoding."
        return
      end
  
      if nick
        if thing.has_flag?(:operator)
          if client = @clients[nick]
            client.data.encoding        = encoding
            client.data.encoding_tested = false
          else
            thing.send :numeric, ERR_NOSUCHNICK, nick
          end
        else
          thing.send :numeric, ERR_NOPRIVILEGES
        end
      else
        thing.data.encoding        = encoding
        thing.data.encoding_tested = false
      end
    end

    on join do |thing, string|
      whole, channels, passwords = string.match(/JOIN\s+(.+?)(?:\s+(.+))?$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, :JOIN
        return
      end
  
      if channels == '0'
        thing.channels.each_value {|channel|
          server.fire :part, channel[thing.nick], 'Left all channels'
        }

        return
      end
  
      channels  = channels.split(/,/)
      passwords = (passwords || '').split(/,/)
  
      channels.each {|channel|
        channel.strip!
  
        if @channels[channel] && @channels[channel].modes[:password]
          password = passwords.shift
        else
          password = nil
        end
  
        server.fire :join, thing, channel, password
      }
    end

    observe :join do |thing, channel, password=nil|
      @semaphore.synchronize {
        if !channel.channel_type
          channel = "##{channel}"
        end

        if !channel.is_valid_channel?
          thing.send :numeric, ERR_BADCHANMASK, channel
          return
        end

        return if thing.channels[channel]

        if @channels[channel]
          channel = @channels[channel]
        else
          channel = @channels[channel] = Channel.new(server, channel)

          channel.modes[:bans]       = []
          channel.modes[:exceptions] = []
          channel.modes[:invites]    = []
          channel.modes[:invited]    = {}
        end

        if channel.modes[:limit]
          if channel.users.length >= channel.modes[:limit]
            thing.send :numeric, ERR_CHANNELISFULL, channel.name

            if channel.modes[:redirect]
              server.fire :join, thing, channel.modes[:redirect]
            end

            return
          end
        end

        if channel.modes[:ssl_only] && !thing.modes[:ssl]
          thing.send :numeric, ERR_SSLREQUIRED, channel.name
          return
        end
  
        if channel.modes[:password] && password != channel.modes[:password]
          thing.send :numeric, ERR_BADCHANNELKEY, channel.name
          return
        end
    
        if channel.modes[:invite_only] && !channel.invited?(thing, true)
          thing.send :numeric, ERR_INVITEONLYCHAN, channel.name
          return
        end
    
        if channel.banned?(thing) && !channel.exception?(thing) && !channel.invited?(thing)
          thing.send :numeric, ERR_BANNEDFROMCHAN, channel.name
          return
        end
      }
    
      server.fire :joined, thing, channel
    end

    observe :joined do |thing, channel|
      empty = channel.empty?
      user  = channel.add(thing)
  
      if empty
        server.fire :mode, server, channel, "+o #{user.nick}", true
      else
        channel.modes[:invited].delete(user.mask)
      end
  
      thing.channels.add(channel)
  
      if user.channel.modes[:anonymous]
        mask = Mask.parse('anonymous!anonymous@anonymous.')
      else
        mask = user.mask
      end
  
      user.channel.send :raw, ":#{mask} JOIN :#{user.channel}"
  
      if !user.channel.topic.nil?
        server.dispatch user.client, "TOPIC #{user.channel}"
      end
  
      server.dispatch user.client, "NAMES #{user.channel}"
    end

    on part do |thing, string|
      whole, channels, reason = string.match(/PART\s+(.+?)(?:\s+:(.*))?$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, 'PART'
        return
      end
  
      channels.split(/,/).each {|name|
        server.fire :part, thing, name, message
      }
    end

    observe :part do |thing, channel, message=nil|
      if !channel.channel_type
        channel = "##{channel}"
      end

      channel = @channels[channel]

      if !channel
        thing.send :numeric, ERR_NOSUCHCHANNEL, name
      elsif !thing.channels[name]
        thing.send :numeric, ERR_NOTONCHANNEL, name
      else
        server.fire :parted, channel.user(thing), message
      end
    end

    observe :parted do |user, message|
      return if user.client.data.quitting
  
      text = (options[:messages][:part] || '#{message}').interpolate(binding)
  
      if user.channel.modes[:anonymous]
        mask = Mask.parse('anonymous!anonymous@anonymous.')
      else
        mask = user.mask
      end
  
      user.channel.send :raw, ":#{mask} PART #{user.channel} :#{text}"

      @semaphore.synchronize {
        user.channel.delete(user)
        user.client.channels.delete(user.channel.name)

        if user.channel.empty?
          @channels.delete(user.channel.name)
        end
      }
    end

    on kick do |thing, string|
      whole, channel, user, message = string.match(/KICK\s+(.+?)\s+(.+?)(?:\s+:(.*))?$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, :KICK
        return
      end
  
      server.fire :kick, thing, channel, user, message
    end

    observe :kick do |from, channel, user, message|
      if !channel.is_valid_channel?
        from.send :numeric, ERR_BADCHANMASK, channel
        return
      end
  
      if !@channels[channel]
        from.send :numeric, ERR_NOSUCHCHANNEL, channel
        return
      end
  
      if !@clients[user]
        from.send :numeric, ERR_NOSUCHNICK, user
        return
      end
  
      channel = @channels[channel]
      user    = channel[user]
  
      if !user
        from.send :numeric, ERR_NOTONCHANNEL, channel.name
        return
      end
  
      if from.channels[channel.name]
        from = channel.user(kicker)
      end
  
      if from.has_flag?(:can_kick)
        if channel.modes[:no_kicks]
          from.send :numeric, ERR_NOKICKS
        else
          server.fire :kicked, from, user, message
        end
      else
        from.send :numeric, ERR_CHANOPRIVSNEEDED, channel.name
      end
    end

    observe :kicked do |from, user, message|
      user.channel.send :raw, ":#{from.mask} KICK #{user.channel} #{user.nick} :#{message}"

      @semaphore.synchronize {
        user.channel.delete(user)
        user.client.channels.delete(user.channel)

        if user.channel.empty?
          @channels.delete(user.channel.name)
        end
      }
    end

    on invite do |thing, string|
      whole, nick, channel = string.match(/INVITE\s+(.+?)\s+(.+?)$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, :INVITE
        return
      end
  
      nick.strip!
      channel.strip!
  
      if !@clients[nick]
        thing.send :numeric, ERR_NOSUCHNICK, nick
        return
      end
  
      if @channels[channel]
        from = @channels[channel].user(thing) || thing
  
        if !from.has_flag?(:can_invite) && !from.channels[channel]
          thing.send :numeric, ERR_NOTONCHANNEL, channel
          return
        end
  
        if !from.has_flag?(:can_invite)
          thing.send :numeric, ERR_CHANOPRIVSNEEDED, channel
          return
        end
  
        if @channels[channel].users[nick]
          thing.send :numeric, ERR_USERONCHANNEL, {
            :nick    => nick,
            :channel => channel,
          }
  
          return
        end
  
        if @channels[channel].modes[:no_invites]
          thing.send :numeric, ERR_NOINVITE, channel
          return
        end
      end
  
      client = @clients[nick]
  
      if client.modes[:away]
        thing.send :numeric, RPL_AWAY, client
      end
  
      server.fire :invite, thing, client, channel
    end

    observe :invite do |from, client, channel|
      from.send :numeric, RPL_INVITING, {
        :nick    => to.nick,
        :channel => channel,
      }
  
      target = channel
  
      if channel = @channels[target]
        channel.modes[:invited][to.mask] = true
        server.fire :notice, ref{:server}, ref{:channel}, "#{from.nick} invited #{to.nick} into the channel.", ?@
      end
  
      client.send :raw, ":#{from.mask} INVITE #{to.nick} :#{target}"
    end

    on names do |thing, string|
      whole, channel = string.match(/NAMES\s+(.*)$/i).to_a

      if !whole
        thing.send :numeric, RPL_ENDOFNAMES, thing.nick
        return
      end

      if channel = thing.channels[channel.strip]
        thing = channel.user(thing)

        if channel.modes[:anonymous]
          users = 'anonymous'
        else
          users = channel.users.map {|(_, user)|
            if channel.modes[:auditorium] && !Utils::User::isLevelEnough(user, '%') && !Utils::checkFlag(thing, :operator)
              if user.modes[:level]
                user.to_s
              end
            else
              user.to_s
            end
          }.compact.join(' ')
        end

        thing.send :numeric, RPL_NAMREPLY, {
          :channel => channel.name,
          :users   => users,
        }
      end

      thing.send :numeric, RPL_ENDOFNAMES, channel
    end

    observe :send do |kind=:message, from, to, message|
      if from.is_a?(User)
        from = from.client
      end

      if match = message.match(/^\x01([^ ]*)( (.*?))?\x01$/)
        server.fire :ctcp, kind, ref{:from}, ref{:to}, match[1], match[3], level
      else
        if kind == :notice
          from.server.fire :notice, :input, ref{:from}, ref{:to}, message, level
        elsif kind == :message
           from.server.fire :message, :input, ref{:from}, ref{:to}, message
        end
      end
    end

    on privmsg do |thing, string|
      whole, receiver, message = string.match(/PRIVMSG\s+(.*?)(?:\s+:(.*))?$/i).to_a
  
      if !receiver
        thing.send :numeric, ERR_NORECIPIENT, :PRIVMSG
        return
      end
  
      if !message
        thing.send :numeric, ERR_NOTEXTTOSEND
        return
      end

      if (level = receiver[0].is_level?) || receiver.is_valid_channel?
        if level
          receiver[0] = ''
        end

        channel = @channels[receiver]
  
        if !channel
          thing.send :numeric, ERR_NOSUCHNICK, receiver
          return
        end
  
        thing = channel.user(thing) || thing
  
        if channel.modes[:moderated] && thing.has_flag?(:can_talk)
          thing.send :numeric, ERR_YOUNEEDVOICE, channel.name
          return
        end
  
        if channel.banned?(thing) && !channel.exception?(thing)
          thing.send :numeric, ERR_YOUAREBANNED, channel.name
          return
        end
  
        if thing.is_a?(User)
          server.fire :send, thing, channel.level(level), message
        else
          if @channels[receiver].modes[:no_external_messages]
            thing.send :numeric, ERR_NOEXTERNALMESSAGES, channel.name
          else
            server.fire :send, thing, channel.level(level), message
          end
        end
      else
        client = @clients[receiver]
  
        if !client
          thing.send :numeric, ERR_NOSUCHNICK, receiver
        else
          server.fire :send, thing, client, message
        end
      end
    end

    observe :message do |chain=:input, from, to, message|
      return unless chain == :input

      case to.value
        when Channel
          if to.value.modes[:strip_colors]
            message.gsub!(/\x03((\d{1,2})?(,\d{1,2})?)?/, '')
          end

          if to.value.modes[:no_colors] && message.include("\x03")
            from.value.send :numeric, ERR_NOCOLORS, to.value.name
            return
          end
          
          to.value.users.each_value {|user|
            next if user.client == from.value

            server.fire :message, :output, from, ref{:user}, message
          }

        when Client
          server.fire :message, :output, from, to, message
      end
    end

    observe :message do |chain=:input, from, to, message|
      return unless chain == :output

      mask = from.value.mask

      case to.value
        when User
          name = to.value.channel.name

          if to.value.channel.modes[:anonymous]
            mask = Mask.parse('anonymous!anonymous@anonymous.')
          end

        when Client
          name = to.value.nick

        else return
      end

      to.value.send :raw, ":#{mask} PRIVMSG #{name} :#{message}"
    end

    on notice do |thing, string|
      whole, receiver, message = string.match(/NOTICE\s+(.*?)\s+:(.*)$/i).to_a
  
      return unless whole
  
      if (level = receiver[0].is_level?) || receiver.is_valid_channel?
        if level
          receiver[0] = ''
        end

        if !(channel = @channels[receiver])
          # unrealircd sends an error if it can't find nick/channel, what should I do?
          return
        end
  
        if !channel.modes[:no_external_messages] || channel.user(thing)
          service :send, :notice, thing, channel.level(level), message
        end
      elsif client = @clients[receiver]
        server.fire :send, :notice, thing, client, message
      end
    end

    observe :notice do |chain=:input, from, to, message|
      return unless chain == :input

      case to.value
        when Channel
          to.value.users.each_value {|user|
            next if user.client == from.value

            server.fire :notice, :output, from, ref{:user}, message
          }

        when Client
          server.fire :notice, :output, from, to, message, level
      end
    end

    observe :notice do |chain=:input, from, to, message|
      return unless chain == :output

      case to.value
        when User
          name = to.value.channel.name
  
          if to.value.channel.modes[:anonymous]
            from = Mask.new 'anonymous', 'anonymous', 'anonymous.'
          end

        when Client
          name = to.value.nick

        else return
      end
  
      to.send :raw, ":#{from} NOTICE #{level}#{name} :#{message}"
    end

    observe :ctcp do |chain=:input, kind=:message, from, to, type, message|
      return unless chain == :input

      case to.value
        when Channel
          if to.value.modes[:no_ctcps]
            from.value.send :numeric, ERR_NOCTCPS, to.value.name
            return false
          end
  
          to.value.users.each_value {|user|
            next if user.client == from.value

            server.fire :ctcp, :output, kind, from, ref{:user}, type, message
          }

        when Client, User
          server.fire :ctcp, :output, kind, from, to, type, message
      end
    end

    observe :ctcp do |chain=:input, kind=:message, from, to, type, message|
      return unless chain == :output

      mask = from.value.mask

      case to.value
        when User
          name = to.value.channel.name

          if to.value.channel.modes[:anonymous]
            mask = Mask.parse('anonymous!anonymous@anonymous.')
          end

        when Client
          name = to.value.nick

        else return
      end
  
      if message
        text = "#{type} #{message}"
      else
        text = type
      end

      case kind
        when :message
          kind  = :PRIVMSG
          level = nil

        when :notice
          kind = :NOTICE
      end
  
      to.value.send :raw, ":#{mask} #{kind} #{level}#{name} :\x01#{text}\x01"
    end
  }
}

end; end
