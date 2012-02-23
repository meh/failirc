#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

require 'failirc/server/modules/base/commands'
require 'failirc/server/modules/base/support'
require 'failirc/server/modules/base/errors'
require 'failirc/server/modules/base/responses'

require 'failirc/server/modules/base/extensions'
require 'failirc/server/modules/base/powers'
require 'failirc/server/modules/base/incoming'
require 'failirc/server/modules/base/servers'
require 'failirc/server/modules/base/clients'
require 'failirc/server/modules/base/users'
require 'failirc/server/modules/base/channels'
require 'failirc/server/modules/base/action'

extend Base

version    '0.1.0'
identifier 'RFC 1460, 2810, 2811, 2812, 2813;'

on :start do |server|
	@mutex      = RecursiveMutex.new
	@joining    = {}
	@pinged_out = []
	@to_ping    = []
	@nicks      = []
	@channels   = Channels.new(server)
	@clients    = {}
	@servers    = {}

	%w[clients servers channels].each {|name|
		mod = self

		server.define_singleton_method name do
			mod.instance_variable_get "@#{name}"
		end
	}

	server.extend Base::Incoming
	server.extend Base::Server

	server.set_interval((options[:misc]['ping timeout'].to_f rescue 60)) {
		@mutex.synchronize {
			# people who didn't answer with a PONG have to YIFF IN HELL.
			@pinged_out.each {|thing|
				thing.disconnect 'Ping timeout'
			}

			@pinged_out.clear

			# time to ping non active users
			@to_ping.each {|thing|
				@pinged_out << thing

				unless thing.incoming?
					thing.send_message "PING :#{server.host}"
				end
			}

			# clear and refill the hash of clients to ping with all the connected clients
			@to_ping.clear
			@to_ping.insert(-1, *server.dispatcher.clients)
		}
	}
end

def check_encoding (string)
	result   = false
	encoding = string.encoding

	%w[UTF-8 ISO-8859-1].each {|encoding|
		string.force_encoding(encoding)

		if string.valid_encoding?
			result = encoding
		end
	}

	string.force_encoding(encoding)

	result
end

# check encoding
input { before priority: -101 do |event, thing, string|
	next unless thing.client?

	begin
		string.force_encoding(thing.encoding)

		if !string.valid_encoding?
			if !thing.encoding_tested && (tmp = check_encoding(string))
				thing.encoding_tested = true
				thing.encoding        = tmp

				string.force_encoding(tmp)
			else
				raise Encoding::InvalidByteSequenceError
			end
		end

		string.encode!('UTF-8')
	rescue
		if thing.encoding
			server.fire :error, thing, 'The encoding you choose seems to not be the one you are using.'
		else
			server.fire :error, thing, 'Please specify the encoding you are using with ENCODING <encoding>'
		end

		string.force_encoding('ASCII-8BIT')

		string.encode!('UTF-8',
			invalid: :replace,
			undef:   :replace
		)
	end
end }

output { after priority: 101 do |event, thing, string|
	return unless thing.client?

	if thing.encoding
		string.encode!(thing.encoding,
			:invalid => :replace,
			:undef   => :replace
		)
	end
end }

input {
	aliases {
		pass /^PASS( |$)/i
		nick /^(:\S\s+)?NICK( |$)/i
		user /^(:\S\s+)?USER( |$)/i

		motd /^MOTD( |$)/i

		ping /^PING( |$)/i
		pong /^PONG( |$)/i

		away      /^AWAY( |$)/i
		hibernate /^HIBERNATE( |$)/i
		mode      /^MODE( |$)/i
		encoding  /^ENCODING( |$)/i

		join   /^(:\S\s+)?JOIN( |$)/i
		part   /^(:\S\s+)?PART( |$)/i
		kick   /^(:\S\s+)?KICK( |$)/i
		invite /^INVITE( |$)/i
		knock  /^KNOCK( |$)/i

		topic /^(:\S\s+)?TOPIC( |$)/i
		names /^NAMES( |$)/i
		list  /^LIST( |$)/i

		who    /^WHO( |$)/i
		whois  /^WHOIS( |$)/i
		whowas /^WHOWAS( |$)/i
		ison   /^ISON( |$)/i

		privmsg /^(:\S\s+)?PRIVMSG( |$)/i
		notice  /^NOTICE( |$)/i

		map     /^MAP( |$)/i
		version /^VERSION( |$)/i

		oper   /^OPER( |$)/i
		kill   /^KILL( |$)/i
		rehash /^REHASH( |$)/i

		quit /^QUIT( |$)/i
	}
}

input {
	observe :connect do |client|
		client.extend Incoming
	end

	# check for ping timeout and registration
	before priority: -99 do |event, thing, string|
		@mutex.synchronize {
			@to_ping.delete(~thing)
			@pinged_out.delete(~thing)
		}

		if thing.client? && Commands::NoAction.none? { |a| event.alias?(a) }
			thing.last_action = Action.new(thing, event, string)
		end

		# if the client tries to do something without having registered, kill it with fire
		if thing.incoming? && Commands::Unregistered.none? { |a| event.alias?(a) }
			thing.send_message ERR_NOTREGISTERED

			skip
		# if the client tries to reregister, kill it with fire
		elsif !thing.incoming? && Commands::Unrepeatable.any? { |a| event.alias?(a) }
			thing.send_message ERR_ALREADYREGISTRED

			skip
		end
	end

	default do |event, thing, string|
		whole, command = string.match(/^([^ ]+)/).to_a

		thing.send_message ERR_UNKNOWNCOMMAND, command
	end

	observe :error do |thing, message, type=nil|
		thing.send_message case type
			when :close then "Closing Link: #{thing.nick}[#{thing.ip}] (#{message})"
			else             "ERROR :#{message}"
		end
	end

	on :cap do |thing, string|
		whole, command = string.match(/CAP\s+(.*?)$/i).to_a

		if !command
			thing.send_message ERR_NEEDMOREPARAMS, :USER
		else
		end
	end

	on :away do |thing, string|
		whole, message = string.match(/AWAY\s+(?::)(.*)$/i).to_a

		if !whole || message.empty?
			thing.away = false
			thing.send_message RPL_UNAWAY
		else
			thing.away = message
			thing.send_message RPL_NOWAWAY
		end
	end

	# this method sends a MOTD string in an RFC compliant way
	def motd (thing, string=nil)
		thing.send_message RPL_MOTDSTART

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

				thing.send_message RPL_MOTD, part.strip
			end
		}

		thing.send_message RPL_ENDOFMOTD
	end

	# This method does some checks trying to register the connection, various checks
	# for nick collisions and such.
	def register (thing)
		return unless thing.incoming?

		# if the client isn't registered but has all the needed attributes, register it
		if thing.temporary.user && thing.temporary.nick
			return false if thing.options[:password] && thing.options[:password] != thing.temporary.password

			(client = thing).extend Client

			client.nick      = thing.temporary.nick
			client.user      = thing.temporary.user
			client.real_name = thing.temporary.real_name

			@clients[client.nick] = client

			server.fire :registered, client

			client.send_message RPL_WELCOME, client
			client.send_message RPL_HOSTEDBY, client
			client.send_message RPL_SERVCREATEDON
			client.send_message RPL_SERVINFO,
				client:  Support::Modes::Client,
				channel: Support::Modes::Channel

			client.send_message RPL_ISUPPORT, Support.to_hash.map {|key, value|
				value != true ? "#{key}=#{value}" : key
			}.join(' ')

			unless client.modes.empty?
				client.send_message ":#{server} MODE #{client.nick} #{client.modes}"
			end

			motd(client)

			server.fire :connected, client
		end
	end

	on :pass do |thing, string|
		next unless thing.incoming?

		whole, password = string.match(/PASS\s+(?::)?(.*)$/i).to_a

		if !password
			thing.send_message ERR_NEEDMOREPARAMS, :PASS
			next
		end

		thing.temporary.password = password

		if thing.options[:password]
			if thing.temporary.password != thing.options[:password]
				server.fire :error, thing, :close, 'Password mismatch'
				thing.disconnect 'Password mismatch'
				next
			end
		end

		# try to register it
		register(thing)
	end

	on :user do |thing, string|
		return unless thing.incoming?

		whole, user, real_name = string.match(/USER\s+([^ ]+)\s+[^ ]+\s+[^ ]+\s+:(.*)$/i).to_a

		if !real_name
			thing.send_message ERR_NEEDMOREPARAMS, :USER
		else
			thing.temporary.user      = user
			thing.temporary.real_name = real_name

			# try to register it
			register(thing)
		end
	end

	def nick_is_ok? (thing, nick)
		if thing.client?
			if thing.nick == nick
				return false
			end

			if thing.nick.downcase == nick.downcase
				return true
			end
		end

		if @nicks.member?(nick)
			thing.send_message ERR_NICKNAMEINUSE, nick

			return false
		end

		if !(eval(options[:misc]['allowed nick']) rescue false) || nick.downcase == 'anonymous'
			thing.send_message ERR_ERRONEUSNICKNAME, nick

			return false
		end

		return true
	end

	on :nick do |thing, string|
		next unless thing.incoming? or thing.client?

		whole, from, nick = string.match(/^(?::(.+?)\s+)?NICK\s+(?::)?(.+)$/i).to_a

		# no nickname was passed, so tell the user is a faggot
		thing.send_message ERR_NONICKNAMEGIVEN and return unless nick

		@mutex.synchronize {
			if thing.incoming?
				if !nick_is_ok?(thing, nick)
					thing.temporary.warned = nick
					return
				end

				@nicks.delete(thing.temporary.nick)
				@nicks << (thing.temporary.nick = nick)

				# try to register it
				register(thing)
			elsif thing.client?
				server.fire :nick, thing, nick
			end
		}
	end

	observe :nick do |thing, nick|
		catch(:no_nick_change) { @mutex.synchronize {  
			next unless nick_is_ok?(thing, nick)

			thing.channels.each_value {|channel|
				if channel.modes.no_nick_change? && !channel.user(thing).is_level_enough?('+')
					thing.send_message ERR_NONICKCHANGE, channel.name

					throw :no_nick_change
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
				thing.send_message ":#{mask} NICK :#{nick}"
			else
				thing.channels.clients.send_message ":#{mask} NICK :#{nick}"
			end
		} }
	end

	on :motd, &method(:motd)

	on :ping do |thing, string|
		whole, what = string.match(/PING\s+(.*)$/i).to_a

		thing.send_message ERR_NOORIGIN and next unless whole

		thing.send_message ":#{server.host} PONG #{server.host} :#{what}"
	end

	on :pong do |thing, string|
		whole, what = string.match(/PONG\s+(?::)?(.*)$/i).to_a

		thing.send_message ERR_NOORIGIN and next unless whole

		if what != server.host
			thing.send_message ERR_NOSUCHSERVER, what
		end
	end

	on :encoding do |thing, string|
		next unless thing.client?

		whole, encoding, nick = string.match(/ENCODING\s+(.+?)(?:\s+(.+))?$/i).to_a

		thing.send_message ERR_NEEDMOREPARAMS, :ENCODING and next unless whole

		if !Encoding.name_list.include?(encoding)
			server.fire :error, thing, "#{encoding} is not a valid encoding."
			return
		end

		if nick
			if thing.can.change_encoding? || thing.can.change_client_flags? 
				if client = @clients[nick]
					client.encoding                  = encoding
					client.temporary.encoding_tested = false
				else
					thing.send_message ERR_NOSUCHNICK, nick
				end
			else
				thing.send_message ERR_NOPRIVILEGES
			end
		else
			thing.encoding                  = encoding
			thing.temporary.encoding_tested = false
		end
	end

	observe :send do |kind=:message, from, to, message|
		if from.is_a?(User)
			from = from.client
		end

		if matches = message.match(/^\x01([^ ]*)( (.*?))?\x01$/)
			server.fire :ctcp, :input, kind, from, to, matches[1], matches[3]
		else
			if kind == :notice
				server.fire :notice, :input, from, to, message
			elsif kind == :message
				 server.fire :message, :input, from, to, message
			end
		end
	end

	on :privmsg do |thing, string|
		whole, receiver, message = string.match(/PRIVMSG\s+(.*?)(?:\s+:(.*))?$/i).to_a

		if !receiver
			thing.send_message ERR_NORECIPIENT, :PRIVMSG
			return
		end

		if !message
			thing.send_message ERR_NOTEXTTOSEND
			return
		end

		if (level = receiver[0].is_level?) || receiver.is_valid_channel?
			if level
				receiver[0] = ''
			end

			channel = @channels[receiver]

			if !channel
				thing.send_message ERR_NOSUCHNICK, receiver
				return
			end

			thing = channel.user(thing) || thing

			if channel.modes.moderated? && thing.can.talk?
				thing.send_message ERR_YOUNEEDVOICE, channel.name
				return
			end

			if channel.banned?(thing) && !channel.exception?(thing)
				thing.send_message ERR_YOUAREBANNED, channel.name
				return
			end

			if thing.is_a?(User)
				server.fire :send, thing, channel.level(level), message
			else
				if @channels[receiver].modes.no_external_messages?
					thing.send_message ERR_NOEXTERNALMESSAGES, channel.name
				else
					server.fire :send, thing, channel.level(level), message
				end
			end
		else
			client = @clients[receiver]

			if !client
				thing.send_message ERR_NOSUCHNICK, receiver
			else
				server.fire :send, thing, client, message
			end
		end
	end

	observe :message do |chain=:input, from, to, message|
		return unless chain == :input

		if to.is_a?(Channel)
			if to.modes.strip_colors?
				message.gsub!(/\x03((\d{1,2})?(,\d{1,2})?)?/, '')
			end

			if to.modes.no_colors? && message.include("\x03")
				from.send_message ERR_NOCOLORS, to.name
				return
			end
			
			to.users.each_value {|user|
				next if from == user.client

				server.fire :message, :output, from, user, message
			}
		elsif to.client?
			server.fire :message, :output, from, to, message
		end
	end

	observe :message do |chain=:input, from, to, message|
		return unless chain == :output

		mask = from.mask

		if to.is_a?(User)
			name = to.channel.name

			if to.channel.modes.anonymous?
				mask = Mask.parse('anonymous!anonymous@anonymous.')
			end
		elsif to.client?
			name = to.nick
		else
			return
		end

		to.send_message ":#{mask} PRIVMSG #{name} :#{message}"
	end

	on :notice do |thing, string|
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

			if !channel.modes.no_external_messages? || channel.user(thing)
				service :send, :notice, thing, channel.level(level), message
			end
		elsif client = @clients[receiver]
			server.fire :send, :notice, thing, client, message
		end
	end

	observe :notice do |chain=:input, from, to, message|
		return unless chain == :input

		if to.is_a?(Channel)
			to.users.each_value {|user|
				next if from == user.client

				server.fire :notice, :output, from, user, message
			}

		elsif to.client?
			server.fire :notice, :output, from, to, message, level
		end
	end

	observe :notice do |chain=:input, from, to, message|
		return unless chain == :output

		if to.is_a?(User)
			name  = to.channel.name
			level = to.channel.level?

			if to.channel.modes.anonymous?
				from = Mask.new 'anonymous', 'anonymous', 'anonymous.'
			end
		elsif to.client?
			name  = to.nick
			level = nil
		else
			return
		end

		to.send_message :raw, ":#{from} NOTICE #{level}#{name} :#{message}"
	end

	observe :ctcp do |chain=:input, kind=:message, from, to, type, message|
		return unless chain == :input

		if to.is_a?(Channel)
			if to.modes.no_ctcps?
				from.send_message ERR_NOCTCPS, to.name

				skip
			end

			to.users.each_value {|user|
				next if from == user.client

				server.fire :ctcp, :output, kind, from, user, type, message
			}

		elsif to.client? || to.is_a?(User)
			server.fire :ctcp, :output, kind, from, to, type, message
		end
	end

	observe :ctcp do |chain=:input, kind=:message, from, to, type, message|
		return unless chain == :output

		mask = from.mask

		if to.is_a?(User)
			name = to.channel.name

			if to.channel.modes.anonymous?
				mask = Mask.parse('anonymous!anonymous@anonymous.')
			end
		elsif to.client?
			name = to.nick
		else
			return
		end

		if message && !message.empty?
			text = "#{type} #{message}"
		else
			text = type
		end

		kind = case ~kind
			when :message then :PRIVMSG
			when :notice  then :NOTICE
		end

		to.send_message ":#{mask} #{kind} #{name} :\x01#{text}\x01"
	end

	on :join do |thing, string|
		return unless thing.client?

		whole, channels, passwords = string.match(/JOIN\s+(.+?)(?:\s+(.+))?$/i).to_a

		thing.send_message ERR_NEEDMOREPARAMS, :JOIN and return unless whole

		if channels == '0'
			thing.channels.each_value {|channel|
				server.fire :part, channel.user(thing), channel.name, 'Left all channels'
			}

			return
		end

		channels  = channels.split(/,/)
		passwords = (passwords || '').split(/,/)

		channels.each {|channel|
			channel.strip!

			if @channels[channel] && @channels[channel].modes.password?
				password = passwords.shift
			else
				password = nil
			end

			server.fire :join, thing, channel, password
		}
	end

	observe :join do |thing, channel, password=nil|
		return unless thing.client?

		@mutex.synchronize {
			if !channel.channel_type
				channel = "##{channel}"
			end

			if !channel.is_valid_channel?
				thing.send_message ERR_BADCHANMASK, channel
				return
			end

			return if thing.is_on_channel?(channel)

			if @channels[channel]
				channel = @channels[channel]
			else
				channel = @channels[channel] = Channel.new(server, channel)
			end

			if channel.modes.limit?
				if channel.users.length >= channel.modes.limit.value
					thing.send_message ERR_CHANNELISFULL, channel.name

					if channel.modes.redirect?
						server.fire :join, thing, channel.modes.redirect.value
					end

					return
				end
			end

			if channel.modes.ssl_only? && !thing.modes.ssl?
				thing.send_message ERR_SSLREQUIRED, channel.name
				return
			end

			if channel.modes.password? && password != channel.modes.password.value
				thing.send_message ERR_BADCHANNELKEY, channel.name
				return
			end
	
			if channel.modes.invite_only? && !channel.invited?(thing, true)
				thing.send_message ERR_INVITEONLYCHAN, channel.name
				return
			end
	
			if channel.banned?(thing) && !channel.exception?(thing) && !channel.invited?(thing)
				thing.send_message ERR_BANNEDFROMCHAN, channel.name
				return
			end
		}
	
		server.fire :joined, thing, channel
	end

	observe :joined do |thing, channel|
		empty = channel.empty?
		user  = channel.add(~thing)

		if empty
			server.fire :mode, server, channel, "+o #{user.nick}", false
		else
			channel.invited.delete(user.mask)
		end

		thing.channels.add(~channel)

		if user.channel.modes.anonymous?
			mask = Mask.parse('anonymous!anonymous@anonymous.')
		else
			mask = user.mask
		end

		user.channel.send_message ":#{mask} JOIN :#{user.channel}"

		if !user.channel.topic.nil?
			server.dispatch :input, user.client, "TOPIC #{user.channel}"
		end

		server.dispatch :input, user.client, "NAMES #{user.channel}"
	end

	on :part do |thing, string|
		whole, channels, message = string.match(/PART\s+(.+?)(?:\s+:(.*))?$/i).to_a

		thing.send_message ERR_NEEDMOREPARAMS, :PART and next unless whole

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
			thing.send_message ERR_NOSUCHCHANNEL, name
		elsif !thing.is_on_channel?(name)
			thing.send_message ERR_NOTONCHANNEL, name
		else
			server.fire :parted, channel.user(thing), message
		end
	end

	observe :parted do |user, message|
		text = (options[:messages][:part] || '#{message}').interpolate(binding)

		if user.channel.modes.anonymous?
			mask = Mask.parse('anonymous!anonymous@anonymous.')
		else
			mask = user.mask
		end

		user.channel.send_message ":#{mask} PART #{user.channel} :#{text}"

		@mutex.synchronize {
			user.channel.delete(user)
			user.client.channels.delete(user.channel.name)

			if user.channel.empty?
				@channels.delete(user.channel.name)
			end
		}
	end

	on :kick do |thing, string|
		whole, channel, user, message = string.match(/KICK\s+(.+?)\s+(.+?)(?:\s+:(.*))?$/i).to_a

		thing.send_message ERR_NEEDMOREPARAMS, :KICK and return unless whole

		server.fire :kick, thing, channel, user, message
	end

	observe :kick do |from, channel, user, message|
		if !channel.is_valid_channel?
			from.send_message ERR_BADCHANMASK, channel
			return
		end

		if !@channels[channel]
			from.send_message ERR_NOSUCHCHANNEL, channel
			return
		end

		if !@clients[user]
			from.send_message ERR_NOSUCHNICK, user
			return
		end

		channel = @channels[channel]
		user    = channel[user]

		if !user
			from.send_message ERR_NOTONCHANNEL, channel.name
			return
		end

		if from.channels[channel.name]
			from = channel.user(from)
		end

		if from.can.kick?
			if channel.modes.no_kicks?
				from.send_message ERR_NOKICKS
			else
				server.fire :kicked, from, user, message
			end
		else
			from.send_message ERR_CHANOPRIVSNEEDED, channel.name
		end
	end

	observe :kicked do |from, user, message|
		user.channel.send_message ":#{from.mask} KICK #{user.channel} #{user.nick} :#{message}"

		@mutex.synchronize {
			user.channel.delete(user)
			user.client.channels.delete(user.channel)

			if user.channel.empty?
				@channels.delete(user.channel.name)
			end
		}
	end

	on :invite do |thing, string|
		whole, nick, channel = string.match(/INVITE\s+(.+?)\s+(.+?)$/i).to_a

		thing.send_message ERR_NEEDMOREPARAMS, :INVITE and next unless whole

		nick.strip!
		channel.strip!

		if !@clients[nick]
			thing.send_message ERR_NOSUCHNICK, nick
			return
		end

		if @channels[channel]
			from = @channels[channel].user(thing) || thing

			if !from.can.invite? && !from.is_on_channel?(channel)
				thing.send_message ERR_NOTONCHANNEL, channel
				return
			end

			if !from.can.invite?
				thing.send_message ERR_CHANOPRIVSNEEDED, channel
				return
			end

			if @channels[channel].users[nick]
				thing.send_message ERR_USERONCHANNEL,
					nick:    nick,
					channel: channel

				return
			end

			if @channels[channel].modes.no_invites?
				thing.send_message ERR_NOINVITE, channel
				return
			end
		end

		client = @clients[nick]

		if client.away?
			thing.send_message RPL_AWAY, client
		end

		server.fire :invite, thing, client, channel
	end

	observe :invite do |from, client, channel|
		from.send_message RPL_INVITING,
			nick:    client.nick,
			channel: channel

		client.send_message ":#{from.mask} INVITE #{client.nick} :#{channel}"

		server.fire :invited, from, client, channel
	end

	observe :invited do |from, client, channel|
		if channel = @channels[channel]
			channel.invited[client.mask] = true
			server.fire :send, :notice, server, channel.level(?@), "#{from.nick} invited #{client.nick} into the channel."
		end
	end

	on :knock do |thing, string|
		whole, channel, message = string.match(/KNOCK\s+(.+?)(?:\s+:(.*))?$/i).to_a

		thing.send_message ERR_NEEDMOREPARAMS, :KNOCK and return unless whole

		if !@channels[channel]
			thing.send_message ERR_NOKNOCK,
				channel: channel,
				reason:  'Channel does not exist!'

			return
		end

		channel = @channels[channel]

		if !channel.modes.invite_only?
			thing.send_message ERR_NOKNOCK,
				channel: channel.name,
				reason:  'Channel is not invite only!'

			return
		end

		if channel.modes.no_knock?
			thing.send_message ERR_NOKNOCK,
				channel: channel.name,
				reason:  'No knocks are allowed! (+K)'

			return
		end

		server.fire :knocked, thing, channel, message
	end

	observe :knocked do |thing, channel, message|
		server.fire :send, :notice, server, channel.level(?@), "[Knock] by #{thing.mask} (#{message ? message : 'no reason specified'})"
		server.fire :send, :notice, server, thing, "Knocked on #{channel.name}"
	end

	on :names do |thing, string|
		whole, channel = string.match(/NAMES\s+(.*)$/i).to_a

		thing.send_message RPL_ENDOFNAMES, thing.nick and return unless whole

		if channel = thing.channels[channel.strip]
			thing = channel.user(thing)

			if channel.modes.anonymous?
				users = 'anonymous'
			else
				users = channel.users.map {|(_, user)|
					if channel.modes.auditorium? && !user.level.enough?('%') && !thing.modes.ircop?
						if user.level
							user.to_s
						end
					else
						user.to_s
					end
				}.compact.join(' ')
			end

			thing.send_message RPL_NAMREPLY,
				channel: channel.name,
				users:   users
		end

		thing.send_message RPL_ENDOFNAMES, channel
	end

	on :topic do |thing, string|
		whole, channel, topic = string.match(/TOPIC\s+(.*?)(?:\s+:(.*))?$/i).to_a

		thing.send_message ERR_NEEDMOREPARAMS, :TOPIC and return unless whole

		channel.strip!

		if !@channels[channel] || (@channels[channel].modes.secret? && !thing.is_on_channel?(channel) && !thing.can.see_secrets?)
			thing.send_message ERR_NOSUCHCHANNEL, channel
			return
		end

		channel = @channels[channel]

		if topic
			server.fire :topic, thing, channel, topic
		else
			if !channel.topic.nil?
				thing.send_message RPL_TOPIC, channel.topic
				thing.send_message RPL_TOPICSETON, channel.topic
			else
				thing.send_message RPL_NOTOPIC, channel
			end
		end
	end

	observe :topic do |from, channel, topic|
		if !from.can.change_topic? && !from.is_on_channel?(channel) && !from.modes.ircop?
			from.send_message ERR_NOTONCHANNEL, channel
			return
		end

		if channel.modes.topic_lock? && !channel.user(from).can.change_topic?
			from.send_message ERR_CHANOPRIVSNEEDED, channel
		else
			if channel.modes.anonymous?
				channel.topic = Mask.new('anonymous', 'anonymous', 'anonymous.'), topic
			else
				channel.topic = from, topic
			end
			
			channel.send_message ":#{channel.topic.set_by} TOPIC #{channel} :#{channel.topic}"
		end
	end

	# MODE user/channel = +option,-option
	on :mode do |thing, string|
		whole, name, value = string.match(/MODE\s+([^ ]+)(?:\s+(?::)?(.*))?$/i).to_a

		thing.send_message ERR_NEEDMOREPARAMS, :MODE and return unless whole

		# long options, extended protocol
		if value && value.match(/^=\s+(.*)$/)
			if name.is_valid_channel?
				if channel = @channels[name]
					server.fire :mode, channel.user(thing) || thing, channel, value
				else
					thing.send_message ERR_NOSUCHCHANNEL, name
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
							thing.send_message ERR_USERNOTINCHANNEL,
								nick:    user,
								channel: channel
						end
					else
						thing.send_message ERR_NOSUCHNICK, user
					end
				else
					thing.send_message ERR_NOSUCHCHANNEL, channel
				end
			else
				if client = @clients[name]
					server.fire :mode, thing, client, value
				else
					thing.send_message ERR_NOSUCHNICK, name
				end
			end
		# usual shit
		else
			if name.is_valid_channel?
				if channel = @channels[name]
					if !value || value.empty?
						thing.send_message RPL_CHANNELMODEIS, channel
						thing.send_message RPL_CHANCREATEDON, channel
					else
						if thing.is_on_channel?(name)
							thing = thing.channels[name].user(thing)
						end

						server.fire :mode, thing, channel, value
					end
				else
					thing.send_message ERR_NOSUCHCHANNEL, name
				end
			else
				if client = @clients[name]
					server.fire :mode, thing, client, value
				else
					thing.send_message ERR_NOSUCHNICK, name
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
						type = :-
					else
						type = :+
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

			type   = (match[1] || '+').to_sym
			modes  = match[2].split(//)
			values = (match[3] || '').strip.split(/ /)

			modes.each {|mode|
				server.fire :mode=, :normal, from, thing, type, mode, values, output
			}

			if from.client? || from.is_a?(User)
				from = from.mask
			end

			if thing.is_a?(Channel)
				name = thing.name

				if thing.modes.anonymous?
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

				thing.send_message ":#{from} MODE #{name} #{string}"
			end
		end
	end

	observe :mode= do |kind, from, thing, type, mode, values, output=nil|
		return unless kind == :normal

		type = ~type
		mode = mode.to_sym

		if thing.is_a?(Channel)
			channel = thing

			case mode

			when :a
				if channel.type != '&' && channel.type != '!'
					server.fire :error, from, 'Only & and ! channels can use this mode.'
					return
				end

				if from.can.change_anonymous_mode?
					return if channel.modes.anonymous? == (type == :+)

					channel.modes.send_message type, :anonymous
					output[:modes].push(:a)
				end

			when :b
				if values.empty?
					channel.bans.each {|ban|
						from.send_message RPL_BANLIST, ban
					}
					
					from.send_message  RPL_ENDOFBANLIST, channel.name
					return
				end

				if from.can.channel_ban?
					mask = Mask.parse(values.shift)

					if type == :+
						if !channel.bans.any? {|ban| ban == mask}
							channel.bans.push(Channel::Modifier.new(from, channel, mask))
						end
					else
						result = channel.bans.delete_if {|ban|
							ban == mask
						}

						mask = nil unless result
					end

					if mask
						output[:modes].push(:b)
						output[:values].push(mask.to_s)
					end
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :c
				if from.can.change_no_colors_mode?
					return if channel.modes.no_colors? == (type == :+)

					channel.modes.send_message type, :no_colors

					output[:modes].push(:c)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :C
				if from.can.change_no_ctcps_mode?
					return if channel.modes.no_ctcps? == (type == :+)

					channel.modes.send_message type, :no_ctcps

					output[:modes].push(:C)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :e
				if values.empty?
					channel.exceptions.each {|exception|
						from.send_message RPL_EXCEPTIONLIST, exception
					}
					
					from.send_message RPL_ENDOFEXCEPTIONLIST, channel.name
					return
				end

				if from.can.add_ban_exception?
					mask = Mask.parse(values.shift)

					if type == :+
						if !channel.exceptions.any? {|exception| exception == mask}
							channel.exceptions.push(Channel::Modifier.new(from, channel, mask))
						end
					else
						result = channel.exceptions.delete_if {|exception|
							exception == mask
						}

						mask = nil if !result
					end

					if mask
						output[:modes].push(:e)
						output[:values].push(mask.to_s)
					end
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :h
				if from.can.give_channel_halfop?
					value = values.shift

					if !value || !(user = channel.users[value])
						from.send_message ERR_NOSUCHNICK, value
						return
					end

					return if user.level.halfop? == (type == :+)

					user.level.send type, :halfop

					output[:modes].push(:h)
					output[:values].push(value)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :i
				if from.can.change_invite_only_mode?
					return if channel.modes.invite_only? == (type == :+)

					channel.modes.send_message type, :invite_only

					output[:modes].push(:i)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :I
				if values.empty?
					channel.invites.each {|invitation|
						from.send_message RPL_INVITELIST, invitation
					}
					
					from.send_message RPL_ENDOFINVITELIST, channel.name
					return
				end

				if from.can.add_invitation?
					mask = Mask.parse(values.shift)

					if type == :+
						if !channel.invites.any? {|invitation| invitation == mask}
							channel.invites.push(Channel::Modifier.new(from, channel, mask))
						end
					else
						result = channel.invites.delete_if {|invitation|
							invitation == mask
						}

						mask = nil if !result
					end

					if mask
						output[:modes].push(:I)
						output[:values].push(mask.to_s)
					end
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :k
				if from.can.change_channel_password?
					value = values.shift

					return if !value

					if type == :+ && (password = value)
						channel.modes + Modes[:password, password]
					else
						password = channel.modes.password.value

						channel.modes - :password
					end

					if password
						output[:modes].push(:k)
						output[:values].push(password)
					end
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :K
				if from.can.change_no_knock_mode?
					return if channel.modes.no_knocks? == (type == :+)

					channel.modes.send_message type, :no_knocks

					output[:modes].push(:K)
					 
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :l
				if from.can.change_limit_mode?
					return if channel.modes.limit? == (type == :+)

					if type == :+
						value = values.shift

						return if !value || !value.match(/^\d+$/)

						channel.modes + Modes[:limit, value.to_i]

						output[:modes].push(:l)
						output[:values].push(value)
					else
						channel.modes - :limit

						output[:modes].push(:l)
					end
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :L
				if from.can.change_redirect_mode?
					return if channel.modes.redirect? == (type == :+)

					if type == :+
						value = values.shift

						return if !value || !value.is_valid_channel?

						channel.modes + Modes[:redirect, value]

						output[:modes].push(:L)
						output[:values].push(value)
					else
						channel.modes - :redirect

						output[:modes].push(:L)
					end
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :m
				if from.can.change_moderated_mode?
					return if channel.modes.moderated? == (type == :+)

					channel.modes.send_message type, :moderated

					output[:modes].push(:m)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :n
				if from.can.change_no_external_messages_mode?
					return if channel.modes.no_external_messages? == (type == :+)

					channel.modes.send_message type, :no_external_messages

					output[:modes].push(:n)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :N
				if from.can.change_no_nick_change_mode?
					return if channel.modes.no_nick_change? == (type == :+)

					channel.send_message type, :no_nick_change

					output[:modes].push(:N)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :o
				if from.can.give_channel_operator?
					value = values.shift

					if !value || !(user = channel.user(value))
						from.send_message ERR_NOSUCHNICK, value
						return
					end

					return if user.level.operator? == (type == :+)

					user.level.send type, :operator

					output[:modes].push(:o)
					output[:values].push(value)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :p
				if from.can.change_private_mode?
					return if channel.modes.secret? || channel.modes.private? == (type == :+)

					channel.modes.send_message type, :private

					output[:modes].push(:p)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :Q
				if from.can.change_no_kicks_mode?
					return if channel.modes.no_kicks? == (type == :+)

					channel.modes.send_message type, :no_kicks

					output[:modes].push(:Q)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :s
				if from.can.change_secret_mode?
					return if channel.modes.private? || channel.modes.secret? == (type == :+)

					channel.modes.send_message type, :secret

					output[:modes].push(:s)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :S
				if from.can.change_strip_colors_mode?
					return if channel.modes.strip_colors? == (type == :+)

					channel.modes.send_message type, :strip_colors

					output[:modes].push(:S)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :t
				if from.can.change_topic_lock_mode?
					return if channel.modes.topic_lock? == (type == :+)

					channel.modes.send_message type, :topic_lock

					output[:modes].push(:t)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :u
				if from.can.change_auditorium_mode?
					return if channel.modes.auditorium? == (type == :+)

					channel.modes.send_message type, :auditorium

					output[:modes].push(:u)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :v
				if from.can.give_channel_voice?
					value = values.shift

					if !value || !(user = channel.users[value])
						from.send_message ERR_NOSUCHNICK, value
						return
					end

					return if user.level.voice? == (type == :+)

					user.level.send type, :voice

					output[:modes].push(:v)
					output[:values].push(value)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :V
				if from.can.change_no_invites_mode?
					return if channel.modes.no_invites? == (type == :+)

					channel.modes.send_message type, :no_invites

					output[:modes].push(:V)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :x
				if from.can.give_channel_owner?
					value = values.shift

					if !value || !(user = channel.users[value])
						from.send_message ERR_NOSUCHNICK, value
						return
					end

					return if user.level.owner? == (type == :+)

					user.level.send type, :owner

					output[:modes].push(:x)
					output[:values].push(value)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :y
				if from.can.give_channel_admin?
					value = values.shift

					if !value || !(user = channel.users[value])
						from.send_message ERR_NOSUCHNICK, value
						return
					end

					return if user.level.admin? == (type == :+)

					user.level.send type, :admin

					output[:modes].push(:y)
					output[:values].push(value)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end

			when :z
				if from.can.change_ssl_mode?
					return if channel.modes.ssl? == (type == :+)

					if type == :+
						begin
							channel.users.each_value {|user|
								raise if !user.ssl?
							}

							channel.modes + :ssl
						rescue
							from.send_message ERR_ALLMUSTUSESSL
							return
						end
					else
						channel.modes - :ssl
					end

					output[:modes].push(:z)
				else
					from.send_message ERR_CHANOPRIVSNEEDED, channel.name
				end
			end
		elsif thing.is_a?(Client)
		end
	end

	observe :mode= do |kind, from, thing, type, mode, values, output=nil|
		return unless kind == :extended
	end

	on :who do |thing, string|
		whole, name, operator = string.match(/WHO\s+(.*?)(?:\s+(o))?$/i).to_a

		thing.send_message RPL_ENDOFWHO and return unless whole

		name ||= '*'

		if name.is_valid_channel? && (channel = @channels[name])
			if channel.modes.anonymous?
				thing.send_message RPL_WHOREPLY,
					channel: channel.name,

					user: {
						nick:      'anonymous',
						user:      'anonymous',
						host:      'anonymous.',
						real_name: 'anonymous',
					},

					server: server.host,
					hops:   0
			else
				channel.users.each_value {|user|
					thing.send_message RPL_WHOREPLY,
						channel: channel.name,

						user: {
							nick:      user.nick,
							user:      user.user,
							host:      user.host,
							real_name: user.real_name,

							level: user.level,
						},

						server: user.server.host,
						hops:   0
				}
			end
		elsif client = @clients[name]
			 thing.send_message RPL_WHOREPLY,
				channel: '*',

				user: {
					nick:      client.nick,
					user:      client.user,
					host:      client.host,
					real_name: client.real_name,
				},

				server: client.server.host,
				hops:   0
		end

		thing.send_message RPL_ENDOFWHO, name
	end

	on :whois do |thing, string|
		matches = string.match(/WHOIS\s+(.+?)(?:\s+(.+?))?$/i)

		thing.send_message ERR_NEEDMOREPARAMS, :WHOIS and return unless matches

		names  = (matches[2] || matches[1]).strip.split(/,/)
		target = matches[2] ? matches[1].strip : nil

		names.each {|name|
			server.fire :whois, thing, name, target
		}
	end

	observe :whois do |thing, name, target=nil|
		unless client = @clients[name]
			thing.send_message ERR_NOSUCHNICK, name

			return
		end

		thing.send_message RPL_WHOISUSER, client

		if thing.modes.ircop? || thing.nick == client.nick
			thing.send_message RPL_WHOISCONNECTING, client
		end

		if thing.modes.ircop?
			thing.send_message RPL_WHOISMODES, client
		end

		if !client.channels.empty?
			thing.send_message RPL_WHOISCHANNELS,
				nick: client.nick,

				channels: client.channels.map {|(name, channel)|
					if ((!channel.modes.secret? && !channel.modes.private?) || thing.is_on_channel?(name)) && !channel.modes.anonymous?
						"#{channel.user(client).level}#{channel.name}"
					end
				}.compact.join(' ')
		end

		thing.send_message RPL_WHOISSERVER, client

		if client.ssl?
			thing.send_message RPL_USINGSSL, client
		end

		if client.away?
			thing.send_message RPL_AWAY, client
		end

		if client.message
			thing.send_message RPL_WHOISOPERATOR, client
		end

		thing.send_message RPL_WHOISIDLE, client
		thing.send_message RPL_ENDOFWHOIS, client
	end

	on :whowas do |thing, string|
		thing.send_message 'PHONE'
	end

	on :ison do |thing, string|
		whole, who = string.match(/ISON\s+(.+)$/i).to_a

		thing.send_message ERR_NEEDMOREPARAMS, :ISON and return unless whole

		thing.send_message RPL_ISON, who.split(/\s+/).map {|nick|
			nick if @clients[nick]
		}.compact.join(' ')
	end

	on :list do |thing, string|
		match, channels = string.match(/LIST(?:\s+(.*))?$/).to_a

		channels = (channels || '').strip.split(/,/)

		thing.send_message RPL_LISTSTART

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
			if !(channel.modes.secret? || channel.modes.private?) || thing.is_on_channel?(channel) || thing.can.see_secrets?
				thing.send_message RPL_LIST,
					name:  channel.name,
					users: channel.modes.anonymous? ? 1 : channel.users.length,
					modes: channel.modes.to_s.empty? ? '' : "[#{channel.modes.to_s}] ",
					topic: channel.topic.text
			end
		}

		thing.send_message RPL_LISTEND
	end

	on :version do |thing, string|
		thing.send_message RPL_VERSION, options[:messages][:version].interpolate(binding)
	end

	on :map do |thing, string|
		server.fire :send, :notice, server, thing, 'The X tells the point.'
	end

	on :oper do |thing, string|
		matches = string.match(/OPER\s+(.*?)(?:\s+(.+?))?$/i)

		thing.send_message ERR_NEEDMOREPARAMS, :OPER and return unless matches

		password = matches[2] || matches[1]
		name     = (matches[2]) ? matches[1] : nil

		mask      = thing.mask.clone
		mask.nick = name if name

		server.options[:operators].each {|operator|
			next unless Mask.parse(operator[:mask]).match(mask) && password == operator[:password]

			operator[:flags].split(/\s*,\s*/).each {|flag|
				thing.modes + flag.to_sym
			}

			thing.message = operator[:message] || 'is an IRC operator'

			thing.send_message RPL_YOUREOPER
			thing.send_message ":#{server} MODE #{thing.nick} #{thing.modes}"

			server.fire :oper, true, thing, name, password

			return
		}

		thing.send_message ERR_NOOPERHOST

		server.fire :oper, false, thing, name, password
	end

	on :kill do |thing, string|
		whole, target, message = string.match(/KILL\s+(.*?)(?:\s+:?(.*))?$/i).to_a

		thing.send_message ERR_NEEDMOREPARAMS, :KILL and return unless whole

		client = @clients[target]

		if !client
			thing.send_message ERR_NOSUCHNICK, nick
			return
		end

		server.fire :kill, thing, client, message
	end

	observe :kill do |from, client, message=nil|
		if !from.can.kill?
			from.send_message ERR_NOPRIVILEGES
			return
		end

		sender = from
		text   = options[:messages][:kill].interpolate(binding)

		client.send_message ":#{client} QUIT :#{text}"
		client.disconnect text
	end

	on :quit do |thing, string|
		whole, message = string.match(/^QUIT(?:\s+:?(.*))?$/i).to_a

		user      = thing
		message ||= user.nick

		thing.disconnect options[:messages][:quit].interpolate(binding)
	end

	observe :disconnect do |thing, message|
		@mutex.synchronize {
			if thing.client?
				@nicks.delete(thing.nick)

				@to_ping.delete(thing)
				@pinged_out.delete(thing)

				thing.channels.select {|name, channel|
					channel.modes.anonymous?
				}.each_key {|name|
					server.fire :part, thing, name, nil
				}

				thing.channels.clients.reject {|nick, client|
					client == ~thing
				}.send_message ":#{thing.mask} QUIT :#{message}"

				thing.channels.each_value {|channel|
					channel.users.delete(thing.nick)

					if channel.empty?
						@channels.delete(channel.name)
					end
				}

				@nicks.delete(thing.nick)
			elsif thing.incoming?
				@nicks.delete(thing.temporary.nick)
			end
		}
	end
}
