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
require 'failirc/modes'
require 'failirc/mask'

module IRC

class Client

class Client
    attr_reader :client, :server, :modes, :mask,

    def initialize (server, mask)
        @client = client
        @server = server
        @mask   = mask

        @modes  = Modes.new
    end

    def nick
        mask.nick
    end

    def user
        mask.user
    end

    def host
        mask.host
    end

    def to_s
        mask.to_s
    end
end

end

end
