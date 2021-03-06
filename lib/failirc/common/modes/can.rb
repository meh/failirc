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

module IRC; class Modes

class Can
	attr_reader :modes

	def initialize (modes)
		@modes = modes
	end

	def method_missing (name, *args)
		name = name.to_s.sub(/\?$/, '').to_sym

		modes.to_hash.values.uniq.select {|mode|
			mode.enabled?
		}.any? {|mode|
			mode.powers.include?(name)
		}
	end
end

end; end
