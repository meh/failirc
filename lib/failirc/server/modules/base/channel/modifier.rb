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

module IRC; class Server; module Base; class Channel

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

end; end; end; end
