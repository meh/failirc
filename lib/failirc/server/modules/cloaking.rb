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

require 'digest/md5'

module IRC; class Server

Module.define('cloaking', '0.0.1') {
  def cloak (host)
    result = host

    options[:keys].each {|key|
      result = Digest::MD5.hexdigest(result, key)
    }

    result
  end

  on registered do |thing|
    return unless thing.is_a?(Client)

    thing.host = cloak(thing.host)
  end
}

end; end
