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

require 'failirc/server/modules/base/user'

module IRC; class Server; module Base

class Users < ThreadSafeHash
	extend Forwardable

	attr_reader    :channel
	def_delegators :@channel, :server

	def initialize (channel, *args)
		@channel = channel

		super(*args)
	end

	def [] (user)
		if user.is_a?(Client) || user.is_a?(User)
			user = user.nick
		end

		super(user)
	end

	def []= (user, value)
		if user.is_a?(Client) || user.is_a?(User)
			user = user.nick
		end

		super(user, value)
	end
	
	def delete (key)
		if key.is_a?(User) || key.is_a?(Client)
			key = key.nick
		end

		key  = key.downcase
		user = self[key]

		super(key) if user

		return user
	end

	def add (user)
		if user.is_a?(User)
			self[user.nick] = user
		else
			self[user.nick] = User.new(user, @channel)
		end
	end

	def send (*args)
		each_value {|user|
			user.send(*args)
		}
	end
end

end; end; end
