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

module IRC; class Server; module Base

module Support
	module Modes
		Client  = 'NZo'
		Channel = 'abcCehiIkKlLmnNoQsStuvVxyz'
	end

	CASEMAPPING = 'ascii'
	SAFELIST    = true
	EXCEPTS     = 'e'
	INVEX       = 'I'
	CHANTYPES   = '&#+!'
	CHANMODES   = 'beI,kfL,lj,acCiKmnNQsStuVz'
	PREFIX      = '(!xyohv)!~&@%+'
	STATUSMSG   = '~&@%+'
	FNC         = true
	CMDS        = 'KNOCK'

	def self.to_hash
		Hash[self.constants.reject {|const|
			true if const == :Modes
		}.map {|const|
			[const, const_get(const)]
		}]
	end
end


end; end; end
