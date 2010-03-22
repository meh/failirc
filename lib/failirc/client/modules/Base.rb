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

require 'failirc/server/module'

module IRC

class Client

module Modules

class Base < Module
    @@version = '0.0.1'

    def self.version
        @@version
    end

    def description
        "Base-#{Base.version}"
    end

    def initialize (client)
        @aliases = {
            :input => {
                :NUMERIC => /^:([^ ]+)\s+(\d{3})\s+(.+)/,
            },
        }

        @events = {
            :input => {
                :NUMERIC => self.method(:numeric),
            },
        }
    end

    def numeric (server, string)

    end
end

end

end

end
