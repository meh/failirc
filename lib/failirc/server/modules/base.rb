#--
# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.doesntexist.org | meh@paranoici.org]
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
  identifier 'RFC 1460, 2810, 2811, 2812, 2813;'

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
      ],

      :channel_moderation => [
        :can_invite, :can_kick, :can_change_topic, :can_change_channel_modes
      ]
    }
  
    def set_flag (type, value, inherited=false, force=false)
      if !inherited
        if value == false
          self.modes.delete(type)
        else
          self.modes[type] = value
        end
      end

      return unless modes = (self.class::Modes[type] || Groups[type])
      
      if !modes.is_a?(Array)
        modes = [modes]
      end
  
      modes.each {|mode|
        if (self.class::Modes[mode] || Groups[mode]) && !self.has_flag?(mode)
          set_flag mode, value, !force
        else
          if value == false
            if !self.class::Modes.has_key?(mode)
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
      :o => [:operator, :can_kill, :can_see_secrets, :can_give_channel_owner, :can_give_channel_admin, :channel_moderation, :can_change_user_modes, :can_change_client_modes],
    }

    Aliases = {
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

    def is_on_channel? (name)
      if name.is_a?(Channel)
        !!name.user(self)
      else
        !!@channels[(name.to_s.is_valid_channel?) ? name : "##{name}"]
      end
    end

    alias __set_flag set_flag

    def set_flag (type, value, inherited=false, force=false)
      __set_flag(Aliases[type] || type, value, inherited, force)
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
      :o => [:h, :operator, :channel_moderation, :can_change_user_modes],
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
    def_delegators :@client, :mask, :server, :data, :nick, :user, :host, :real_name, :send, :channels, :is_on_channel?
  
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
  
      highest = highest_level
  
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
        return level if modes[level]
      }
    end
  
    def set_level (level, value)
      if Levels[level]
        set_flag level, value
  
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
  
    alias _get_ [] 
    alias _set_ []=
    alias _delete_ delete
  
    def [] (user)
      if user.is_a?(Client) || user.is_a?(User)
        user = user.nick
      end
  
      _get_(user)
    end
  
    def []= (user, value)
      if user.is_a?(Client) || user.is_a?(User)
        user = user.nick
      end
  
      _set_(user, value)
    end
    
    def delete (key)
      if key.is_a?(User) || key.is_a?(Client)
        key = key.nick
      end
  
      key = key.downcase
      user = self[key]
  
      _delete_(key) if user

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
          @set_on = Time.now
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

    class Modifier
      attr_reader :set_by, :set_on, :channel, :mask

      def initialize (by, channel, mask)
        @set_by  = by.mask.clone
        @set_on  = Time.now
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
        "#{channel} #{mask} #{set_by.nick} #{set_on.tv_sec}"
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

    attr_reader    :server, :name, :type, :created_on, :modes, :topic, :data
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
      @data       = OpenStruct.new
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
        users = Users.new(self)
        
        @users.select {|_, user|
          user.is_level_enough?(@level)
        }.each {|_, user|
          user    = user.clone
          channel = self

          user.instance_eval '@channel = channel'

          users.add(user)
        }

        users
      else
        @users
      end
    end
  
    def user (client)
      @users[client]
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
      return true if shallow && !channel.has_flag?(:invite_only)

      return true if channel.data.invited[client.mask]

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
      return self unless User::Levels.has_value?(level)

      result       = self.clone
      result.level = level

      result
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
    server.define_singleton_method :has_flag? do |flag| true end

    @supported_modes = {
      :client  => 'Nzo',
      :channel => 'abcCehiIkKlLmnNoQsStuvVxyz'
    }

    @support = { 
      CASEMAPPING: 'ascii',
      SAFELIST:    true,
      EXCEPTS:     'e',
      INVEX:       'I',
      CHANTYPES:   '&#+!',
      CHANMODES:   'beI,kfL,lj,acCiKmnNQsStuVz',
      PREFIX:      '(!xyohv)!~&@%+',
      STATUSMSG:   '~&@%+',
      FNC:         true,

      CMDS: 'KNOCK'
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
  input do before -10001 do |event, thing, string|
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

  output do after 10001 do |event, thing, string|
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

      away      /^AWAY( |$)/i
      hibernate /^HIBERNATE( |$)/i
      mode      /^MODE( |$)/i
      encoding  /^ENCODING( |$)/i

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
  
        server.fire :registered, client

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
          if channel.has_flag?(:no_nick_change) && !channel.user(thing).is_level_enough?('+')
            thing.send :numeric, ERR_NONICKCHANGE, channel.name
            return
          end
        }

        @nicks.delete(thing.nick)
        @nicks << nick

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
        thing.data.real_name = real_name
  
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
    
    on hibernate do |thing, string|

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
              if thing.is_on_channel?(name)
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
      if match = request.match(/^=(.*)$/)
        value = match[1].strip
  
        if value == '?'
          # TODO
        else
          modes = value.split(/[^\\],/)
    
          modes.each {|mode|
            if mode.start_with?('-')
              type = '-'
            else
              type = '+'
            end
    
            mode.sub!(/^[+\-]/, '')
    
            mode = mode.split(/=/)
    
            server.fire :mode=, :extended, from, thing, type, *mode
          }
        end
      else
        output = {
          :modes  => [],
          :values => [],
        }
  
        return false unless match = request.match(/^\s*([+\-])?\s*([^ ]+)(?:\s+(.+))?$/)
  
        type   = match[1] || '+'
        modes  = match[2].split(//)
        values = (match[3] || '').strip.split(/ /)
  
        modes.each {|mode|
          server.fire :mode=, :normal, from, thing, type, mode, values, output
        }
  
        if from.is_a?(Client) || from.is_a?(User)
          from = from.mask
        end
  
        if thing.is_a?(Channel)
          name = thing.name
  
          if thing.modes[:anonymous]
            from = Mask.parse('anonymous!anonymous@anonymous.')
          end
        else
          name = thing.nick
        end
  
        if answer && (!output[:modes].empty? || !output[:values].empty?)
          string = "#{type}#{output[:modes].join('')}"
          
          if !output[:values].empty?
            string << " #{output[:values].join(' ')}"
          end
  
          thing.send :raw, ":#{from} MODE #{name} #{string}"
        end
      end
    end

    observe :mode= do |kind, from, thing, type, mode, values, output=nil|
      return unless kind == :normal

      mode = mode.to_sym

      if thing.is_a?(Channel)
        case mode
  
        when :a
          if thing.type != '&' && thing.type != '!'
            server.fire :error, from, 'Only & and ! channels can use this mode.'
            return
          end
  
          if from.has_flag?(:can_change_anonymous_mode)
            return if thing.check_flag?(:a) == (type == '+')
  
            thing.set_flag(:a, type == '+')
            output[:modes].push(:a)
          end
  
        when :b
          if values.empty?
            thing.modes[:bans].each {|ban|
              from.send :numeric, RPL_BANLIST, ban
            }
            
            from.send :numeric, RPL_ENDOFBANLIST, thing.name
            return
          end
  
          if from.has_flag?(:can_channel_ban)
            mask = Mask.parse(values.shift)
  
            if type == '+'
              if !thing.modes[:bans].any? {|ban| ban == mask}
                thing.modes[:bans].push(Channel::Modifier.new(from, thing, mask))
              end
            else
              result = thing.modes[:bans].delete_if {|ban|
                ban == mask
              }
  
              mask = nil unless result
            end
  
            if mask
              output[:modes].push(:b)
              output[:values].push(mask.to_s)
            end
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :c
          if from.has_flag?(:can_change_nocolors_mode)
            return if thing.has_flag?(:c) == (type == '+')
  
            thing.set_flag(:c, type == '+')
  
            output[:modes].push(:c)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :C
          if from.has_flag?(:can_change_noctcp_mode)
            return if thing.has_flag?(:C) == (type == '+')
  
            thing.set_flag(:C, type == '+')
  
            output[:modes].push(:C)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :e
          if values.empty?
            thing.modes[:exceptions].each {|exception|
              from.send :numeric, RPL_EXCEPTIONLIST, exception
            }
            
            from.send :numeric, RPL_ENDOFEXCEPTIONLIST, thing.name
            return
          end
  
          if from.has_flag?(:can_add_ban_exception)
            mask = Mask.parse(values.shift)
  
            if type == '+'
              if !thing.modes[:exceptions].any? {|exception| exception == mask}
                thing.modes[:exceptions].push(Channel::Modifier.new(from, thing, mask))
              end
            else
              result = thing.modes[:exceptions].delete_if {|exception|
                exception == mask
              }
  
              mask = nil if !result
            end
  
            if mask
              output[:modes].push(:e)
              output[:values].push(mask.to_s)
            end
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :h
          if from.has_flag?(:can_give_channel_half_operator)
            value = values.shift
  
            if !value || !(user = thing.users[value])
              from.send :numeric, ERR_NOSUCHNICK, value
              return
            end
  
            return if user.has_flag?(:h, true) == (type == '+')
  
            user.set_level :h, (type == '+')
  
            output[:modes].push(:h)
            output[:values].push(value)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :i
          if from.has_flag?(:can_change_invite_only_mode)
            return if thing.has_flag?(:i) == (type == '+')
  
            thing.set_flag :i, type == '+'
  
            output[:modes].push('i')
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :I
          if values.empty?
            thing.modes[:invites].each {|invitation|
              from.send :numeric, RPL_INVITELIST, invitation
            }
            
            from.send :numeric, RPL_ENDOFINVITELIST, thing.name
            return
          end
  
          if from.has_flag?(:can_add_invitation)
            mask = Mask.parse(values.shift)
  
            if type == '+'
              if !thing.modes[:invites].any? {|invitation| invitation == mask}
                thing.modes[:invites].push(Channel::Modifier.new(from, thing, mask))
              end
            else
              result = thing.modes[:invites].delete_if {|invitation|
                invitation == mask
              }
  
              mask = nil if !result
            end
  
            if mask
              output[:modes].push(:I)
              output[:values].push(mask.to_s)
            end
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :k
          if from.has_flag?(:can_change_channel_password)
            value = values.shift
  
            return if !value
  
            if type == '+' && (password = value)
              thing.set_flag :k, password
            else
              password = thing.modes[:password]
  
              thing.set_flag :k, false
            end
  
            if password
              output[:modes].push(:k)
              output[:values].push(password)
            end
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :K
          if from.has_flag?(:can_change_noknock_mode)
            return if thing.has_flag?(:K) == (type == '+')
  
            thing.set_flag :K, type == '+'
  
            output[:modes].push(:K)
             
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :l
          if from.has_flag?(:can_change_limit_mode)
            return if thing.has_flag?(:l) == (type == '+')

            if type == '+'
              value = values.shift
  
              return if !value || !value.match(/^\d+$/)
  
              thing.set_flag :l, value.to_i
  
              output[:modes].push(:l)
              output[:values].push(value)
            else
              thing.set_flag :l, false
  
              output[:modes].push(:l)
            end
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :L
          if from.has_flag?(:can_change_redirect_mode)
            return if thing.has_flag?(:L) == (type == '+')
  
            if type == '+'
              value = values.shift
  
              return if !value || !value.is_valid_channel?
  
              thing.set_flag :L, value
  
              output[:modes].push(:L)
              output[:values].push(value)
            else
              thing.set_flag :L, false
  
              output[:modes].push(:L)
            end
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :m
          if from.has_flag?(:can_change_moderated_mode)
            return if thing.has_flag?(:m) == (type == '+')
  
            thing.set_flag :m, type == '+'
  
            output[:modes].push(:m)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :n
          if from.has_flag?(:can_change_no_external_messages_mode)
            return if thing.has_flag?(:n) == (type == '+')
  
            thing.set_flag :n, type == '+'
  
            output[:modes].push(:n)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :N
          if from.has_flag?(:can_change_no_nick_change_mode)
            return if thing.has_flag?(:N) == (type == '+')
  
            thing.set_flag :N, type == '+'
  
            output[:modes].push(:N)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :o
          if from.has_flag?(:can_give_channel_operator)
            value = values.shift
  
            if !value || !(user = thing.user(value))
              from.send :numeric, ERR_NOSUCHNICK, value
              return
            end
  
            return if user.has_flag?(:o, true) == (type == '+')
  
            user.set_level :o, (type == '+')
  
            output[:modes].push(:o)
            output[:values].push(value)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :p
          if from.has_flag?(:can_change_private_mode)
            return if thing.modes[:secret] || thing.has_flag?(:p) == (type == '+')
  
            thing.set_flag :p, type == '+'
  
            output[:modes].push(:p)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
  
        when :Q
          if from.has_flag?(:can_change_nokicks_mode)
            return if thing.has_flag?(:Q) == (type == '+')
  
            thing.set_flag :Q, type == '+'
  
            output[:modes].push(:Q)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :s
          if from.has_flag?(:can_change_secret_mode)
            return if thing.has_flag?(:s) == (type == '+') || thing.modes[:private]
  
            thing.set_flag :s, type == '+'
  
            output[:modes].push(:s)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :S
          if from.has_flag?(:can_change_strip_colors_mode)
            return if thing.has_flag?(:S) == (type == '+')
  
            thing.set_flag :S, type == '+'
  
            output[:modes].push(:S)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :t
          if from.has_flag?(:can_change_topic_mode)
            return if thing.has_flag?(:t) == (type == '+')
  
            thing.set_flag :t, type == '+'
  
            output[:modes].push(:t)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :u
          if from.has_flag?(:can_change_auditorium_mode)
            return if thing.has_flag?(:u) == (type == '+')
  
            thing.set_flag :u, type == '+'
  
            output[:modes].push(:u)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :v
          if from.has_flag?(:can_give_voice)
            value = values.shift
  
            if !value || !(user = thing.users[value])
              from.send :numeric, ERR_NOSUCHNICK, value
              return
            end
  
            return if user.has_flag?(:v, true) == (type == '+')
  
            user.set_level :v, (type == '+')
  
            output[:modes].push(:v)
            output[:values].push(value)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :V
          if from.has_flag?(:can_change_noinvites_mode)
            return if thing.has_flag?(:V) == (type == '+')
  
            thing.set_flag :V, type == '+'
  
            output[:modes].push('V')
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :x
          if from.has_flag?(:can_give_channel_owner)
            value = values.shift
  
            if !value || !(user = thing.users[value])
              from.send :numeric, ERR_NOSUCHNICK, value
              return
            end
  
            return if user.has_flag?(:x, true) == (type == '+')
  
            user.set_level :x, (type == '+')
  
            output[:modes].push(:x)
            output[:values].push(value)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :y
          if from.has_flag?(:can_give_channel_admin)
            value = values.shift
  
            if !value || !(user = thing.users[value])
              from.send :numeric, ERR_NOSUCHNICK, value
              return
            end
  
            return if user.has_flag?(:y, true) == (type == '+')
  
            user.set_level :y, (type == '+')
  
            output[:modes].push(:y)
            output[:values].push(value)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
  
        when :z
          if from.has_flag?(:can_change_ssl_mode)
            return if thing.has_flag?(:z) == (type == '+')
  
            if type == '+'
              ok = true
  
              thing.users.each_value {|user|
                if !user.has_flag?(:ssl)
                  ok = false
                  break
                end
              }
  
              if ok
                thing.set_flag :z, true
              else
                from.send :numeric, ERR_ALLMUSTUSESSL
                return
              end
            else
              thing.set_flag :z, false
            end
  
            output[:modes].push(:z)
          else
            from.send :numeric, ERR_CHANOPRIVSNEEDED, thing.name
          end
        end
      elsif thing.is_a?(Client)
      end
    end

    observe :mode= do |kind, from, thing, type, mode, values, output=nil|
      return unless kind == :extended
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
  
        if @channels[channel] && @channels[channel].has_flag?(:password)
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

        return if thing.is_on_channel?(channel)

        if @channels[channel]
          channel = @channels[channel]
        else
          channel = @channels[channel] = Channel.new(server, channel)

          channel.modes[:bans]       = []
          channel.modes[:exceptions] = []
          channel.modes[:invites]    = []
          channel.modes[:invited]    = {}
        end

        if channel.has_flag?(:limit)
          if channel.users.length >= channel.modes[:limit]
            thing.send :numeric, ERR_CHANNELISFULL, channel.name

            if channel.has_flag?(:redirect)
              server.fire :join, thing, channel.modes[:redirect]
            end

            return
          end
        end

        if channel.has_flag?(:ssl_only) && !thing.has_flag?(:ssl)
          thing.send :numeric, ERR_SSLREQUIRED, channel.name
          return
        end
  
        if channel.has_flag?(:password) && password != channel.modes[:password]
          thing.send :numeric, ERR_BADCHANNELKEY, channel.name
          return
        end
    
        if channel.has_flag?(:invite_only) && !channel.invited?(thing, true)
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
        server.fire :mode, server, channel, "+o #{user.nick}", false
      else
        channel.modes[:invited].delete(user.mask)
      end
  
      thing.channels.add(channel)
  
      if user.channel.has_flag?(:anonymous)
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
      whole, channels, message = string.match(/PART\s+(.+?)(?:\s+:(.*))?$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, :PART
        return
      end
  
      channels.split(/,/).each {|name|
        server.fire :part, thing, name, message
      }
    end

    observe :part do |thing, name, message=nil|
      if !name.channel_type
        name = "##{name}"
      end

      channel = @channels[name]

      if !channel
        thing.send :numeric, ERR_NOSUCHCHANNEL, name
      elsif !thing.is_on_channel?(name)
        thing.send :numeric, ERR_NOTONCHANNEL, name
      else
        server.fire :parted, channel.user(thing), message
      end
    end

    observe :parted do |user, message|
      return if user.client.data.quitting

      text = (options[:messages][:part] || '#{message}').interpolate(binding)
  
      if user.channel.has_flag?(:anonymous)
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
        from = channel.user(from)
      end

      if from.has_flag?(:can_kick)
        if channel.has_flag?(:no_kicks)
          from.send :numeric, ERR_NOKICKS
        else
          server.fire :kicked, ref{:from}, user, message
        end
      else
        from.send :numeric, ERR_CHANOPRIVSNEEDED, channel.name
      end
    end

    observe :kicked do |from, user, message|
      user.channel.send :raw, ":#{from.value.mask} KICK #{user.channel} #{user.nick} :#{message}"

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
  
        if !from.has_flag?(:can_invite) && !from.is_on_channel?(channel)
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
  
        if @channels[channel].has_flag?(:no_invites)
          thing.send :numeric, ERR_NOINVITE, channel
          return
        end
      end
  
      client = @clients[nick]
  
      if client.has_flag?(:away)
        thing.send :numeric, RPL_AWAY, client
      end
  
      server.fire :invite, thing, client, channel
    end

    observe :invite do |from, client, channel|
      from.send :numeric, RPL_INVITING, {
        :nick    => client.nick,
        :channel => channel,
      }
  
      target = channel
  
      if channel = @channels[target]
        channel.modes[:invited][client.mask] = true
        server.fire :send, :notice, server, channel.level(?@), "#{from.nick} invited #{client.nick} into the channel."
      end
  
      client.send :raw, ":#{from.mask} INVITE #{client.nick} :#{target}"
    end

    on names do |thing, string|
      whole, channel = string.match(/NAMES\s+(.*)$/i).to_a

      if !whole
        thing.send :numeric, RPL_ENDOFNAMES, thing.nick
        return
      end

      if channel = thing.channels[channel.strip]
        thing = channel.user(thing)

        if channel.has_flag?(:anonymous)
          users = 'anonymous'
        else
          users = channel.users.map {|(_, user)|
            if channel.has_flag?(:auditorium) && !user.is_level_enough?('%') && !thing.has_flag?(:operator)
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

    on knock do |thing, string|
      whole, channel, message = string.match(/KNOCK\s+(.+?)(?:\s+:(.*))?$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, :KNOCK
        return
      end
  
      if !@channels[channel]
        thing.send :numeric, ERR_NOKNOCK, { :channel => channel, :reason => 'Channel does not exist!' }
        return
      end
  
      channel = @channels[channel]
  
      if !channel.has_flag?(:invite_only)
        thing.send :numeric, ERR_NOKNOCK, { :channel => channel.name, :reason => 'Channel is not invite only!' }
        return
      end
  
      if channel.has_flag?(:no_knock)
        thing.send :numeric, ERR_NOKNOCK, { :channel => channel.name, :reason => 'No knocks are allowed! (+K)' }
        return
      end
  
      server.fire :send, :notice, server, channel.level(?@), "[Knock] by #{thing.mask} (#{message ? message : 'no reason specified'})"
      server.fire :send, :notice, server, thing, "Knocked on #{channel.name}"
    end

    on topic do |thing, string|
      whole, channel, topic = string.match(/TOPIC\s+(.*?)(?:\s+:(.*))?$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, :TOPIC
        return
      end
  
      server.fire :topic, ref{:thing}, channel.strip, topic
    end

    observe :topic do |from, channel, topic|
      if !@channels[channel] || (@channels[channel].has_flag?(:secret) && !from.value.is_on_channel?(channel))
        from.send :numeric, ERR_NOSUCHCHANNEL, channel
        return
      end
  
      channel = @channels[channel]
  
      if !topic
        if !channel.topic.nil?
          from.value.send :numeric, RPL_TOPIC, channel.topic
          from.value.send :numeric, RPL_TOPICSETON, channel.topic
        else
          from.value.send :numeric, RPL_NOTOPIC, channel
        end

        return
      end
      
      if !from.value.has_flag?(:can_change_topic) && !from.value.is_on_channel?(channel) && !from.value.has_flag?(:operator)
        from.value.send :numeric, ERR_NOTONCHANNEL, channel
        return
      end
 
      if channel.has_flag?(:topic_lock) && !channel.user(from.value).has_flag?(:can_change_topic)
        from.value.send :numeric, ERR_CHANOPRIVSNEEDED, channel
      else
        if channel.has_flag?(:anonymous)
          channel.topic = Mask.new('anonymous', 'anonymous', 'anonymous.'), topic
        else
          channel.topic = from.value, topic
        end
        
        channel.send :raw, ":#{channel.topic.set_by} TOPIC #{channel} :#{channel.topic}"
      end
    end

    on list do |thing, string|
      match, channels = string.match(/LIST(?:\s+(.*))?$/).to_a
  
      channels = (channels || '').strip.split(/,/)
  
      thing.send :numeric, RPL_LISTSTART
  
      if channels.empty?
        channels = @channels
      else
        tmp = Channels.new(thing.server)
  
        channels.each {|channel|
          tmp.add(@channels[channel]) if @channels[channel]
        }
  
        channels = tmp
      end
  
      channels.each_value {|channel|
        if !(channel.has_flag?(:secret) || channel.has_flag?(:private)) || thing.is_on_channel?(channel) || thing.has_flag?(:can_see_secrets)
          thing.send :numeric, RPL_LIST, {
            :name  => channel.name,
            :users => channel.has_flag?(:anonymous) ? 1 : channel.users.length,
            :modes => channel.modes.to_s.empty? ? '' : "[#{channel.modes.to_s}] ",
            :topic => channel.topic.text,
          }
        end
      }
  
      thing.send :numeric, RPL_LISTEND
    end

    on who do |thing, string|
      whole, name, operator = string.match(/WHO\s+(.*?)(?:\s+(o))?$/i).to_a
  
      if !whole
        thing.send :numeric, RPL_ENDOFWHO
        return
      end

      name ||= '*'

      if name.is_valid_channel? && (channel = @channels[name])
        if channel.has_flag?(:anonymous)
          thing.send :numeric, RPL_WHOREPLY, {
            :channel => channel.name,

            :user => {
              :nick      => 'anonymous',
              :user      => 'anonymous',
              :host      => 'anonymous.',
              :real_name => 'anonymous',
            },

            :server => server.host,

            :hops => 0
          }
        else
          channel.users.each_value {|user|
            thing.send :numeric, RPL_WHOREPLY, {
              :channel => channel.name,

              :user => {
                :nick      => user.nick,
                :user      => user.user,
                :host      => user.host,
                :real_name => user.real_name,

                :level => user.modes[:level],
              },

              :server => user.server.host,

              :hops => 0
            }
          }
        end
      elsif client = @clients[name]
         thing.send :numeric, RPL_WHOREPLY, {
          :channel => '*',

          :user => {
            :nick      => client.nick,
            :user      => client.user,
            :host      => client.host,
            :real_name => client.real_name,
          },

          :server => client.server.host,

          :hops => 0
        }
      end

      thing.send :numeric, RPL_ENDOFWHO, name
    end

    on whois do |thing, string|
      matches = string.match(/WHOIS\s+(.+?)(?:\s+(.+?))?$/i)
  
      if !matches
        thing.send :numeric, ERR_NEEDMOREPARAMS, :WHOIS
        return
      end
  
      names  = (matches[2] || matches[1]).strip.split(/,/)
      target = matches[2] ? matches[1].strip : nil
  
      names.each {|name|
        server.fire :whois, thing, name, target
      }
    end

    observe :whois do |thing, name, target=nil|
      unless client = @clients[name]
        thing.send :numeric, ERR_NOSUCHNICK, name
        return
      end
  
      thing.send :numeric, RPL_WHOISUSER, client
  
      if thing.has_flag?(:operator)
        thing.send :numeric, RPL_WHOISMODES, client
        thing.send :numeric, RPL_WHOISCONNECTING, client
      end
  
      if !client.channels.empty?
        thing.send :numeric, RPL_WHOISCHANNELS, {
          :nick     => client.nick,
          :channels => client.channels.map {|(name, channel)|
            if ((!channel.has_flag?(:secret) && !channel.has_flag?(:private)) || thing.is_on_channel?(name)) && !channel.modes[:anonymous]
              "#{channel.user(client).modes[:level]}#{channel.name}"
            end
          }.compact.join(' ')
        }
      end
  
      thing.send :numeric, RPL_WHOISSERVER, client
  
      if client.has_flag?(:ssl)
        thing.send :numeric, RPL_USINGSSL, client
      end
  
      if client.has_flag?(:away)
        thing.send :numeric, RPL_AWAY, client
      end
  
      if client.has_flag?(:message)
        thing.send :numeric, RPL_WHOISOPERATOR, client
      end
  
      thing.send :numeric, RPL_WHOISIDLE, client
      thing.send :numeric, RPL_ENDOFWHOIS, client
    end

    on whowas do |thing, string|
      thing.send :raw, 'PHONE'
    end

    on ison do |thing, string|
      whole, who = string.match(/ISON\s+(.+)$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, :ISON
        return
      end
  
      thing.send :numeric, RPL_ISON, who.split(/\s+/).map {|nick|
        nick if @clients[nick]
      }.compact.join(' ')
    end

    observe :send do |kind=:message, from, to, message|
      if from.is_a?(User)
        from = from.client
      end

      if match = message.match(/^\x01([^ ]*)( (.*?))?\x01$/)
        server.fire :ctcp, kind, ref{:from}, ref{:to}, match[1], match[3], level
      else
        if kind == :notice
          server.fire :notice, :input, ref{:from}, ref{:to}, message, level
        elsif kind == :message
           server.fire :message, :input, ref{:from}, ref{:to}, message
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
  
        if channel.has_flag?(:moderated) && thing.has_flag?(:can_talk)
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
          if @channels[receiver].has_flag?(:no_external_messages)
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
          if to.value.has_flag?(:strip_colors)
            message.gsub!(/\x03((\d{1,2})?(,\d{1,2})?)?/, '')
          end

          if to.value.has_flag?(:no_colors) && message.include("\x03")
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

          if to.value.channel.has_flag?(:anonymous)
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
  
        if !channel.has_flag?(:no_external_messages)|| channel.user(thing)
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
          name  = to.value.channel.name
          level = to.value.channel.level?
  
          if to.value.channel.has_flag?(:anonymous)
            from = Mask.new 'anonymous', 'anonymous', 'anonymous.'
          end

        when Client
          name  = to.value.nick
          level = nil

        else return
      end
  
      to.value.send :raw, ":#{from.value} NOTICE #{level}#{name} :#{message}"
    end

    observe :ctcp do |chain=:input, kind=:message, from, to, type, message|
      return unless chain == :input

      case to.value
        when Channel
          if to.value.has_flag?(:no_ctcps)
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

          if to.value.channel.has_flag?(:anonymous)
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

    on map do |thing, string|
      server.fire :send, :notice, server, thing, 'The X tells the point.'
    end

    on :version do |thing, string|
      thing.send :numeric, RPL_VERSION, options[:messages][:version].interpolate(binding)
    end

    on oper do |thing, string|
      matches = string.match(/OPER\s+(.*?)(?:\s+(.+?))?$/i).to_a
  
      if !matches
        thing.send :numeric, ERR_NEEDMOREPARAMS, :OPER
        return
      end
  
      password = matches[2] || matches[1]
      name     = (matches[2]) ? matches[1] : nil
  
      mask = thing.mask.clone
  
      mask.nick = name if name

      server.options[:operators].each {|operator|
        next unless Mask.parse(operator[:mask]).match(mask) && password == operator[:password]

        operator[:flags].split(/\s*,\s*/).each {|flag|
          thing.set_flag flag.to_sym, true, false, true
        }
  
        thing.modes[:message] = 'is an IRC operator'
  
        thing.send :numeric, RPL_YOUREOPER
        thing.send :raw, ":#{server} MODE #{thing.nick} #{thing.modes}"
  
        server.fire :oper, true, thing, name, password

        return
      }
  
      thing.send :numeric, ERR_NOOPERHOST
      server.fire :oper, false, thing, name, password
    end

    on kill do |thing, string|
      whole, target, message = string.match(/KILL\s+(.*?)(?:\s+:?(.*))?$/i).to_a
  
      if !whole
        thing.send :numeric, ERR_NEEDMOREPARAMS, :KILL
        return
      end
  
      client = @clients[target]
  
      if !client
        thing.send :numeric, ERR_NOSUCHNICK, nick
        return
      end
  
      server.fire :kill, ref{:thing}, client, message
    end

    observe :kill do |from, client, message=nil|
      if !from.value.has_flag?(:can_kill)
        from.value.send :numeric, ERR_NOPRIVILEGES
        return
      end

      sender = from.value
      text   = options[:messages][:kill].interpolate(binding)

      client.send :raw, ":#{client} QUIT :#{text}"
      server.kill client, text
    end

    on quit do |thing, string|
      whole, message = string.match(/^QUIT(?:\s+:?(.*))?$/i).to_a

      user      = thing
      message ||= user.nick

      server.kill(thing, options[:messages][:quit].interpolate(binding))
    end

    observe :killed do |thing, message|
      return unless thing.is_a?(Client)

      @nicks.delete(thing.data.nick)

      @to_ping.delete(thing.socket)
      @pinged_out.delete(thing.socket)
  
      thing.channels.select {|name, channel|
        channel.has_flag?(:anonymous)
      }.each_key {|name|
        server.fire :part, thing, name, nil
      }
  
      thing.channels.unique_users.send :raw, ":#{thing.mask} QUIT :#{message}"
    end
  }
}

end; end
