# failirc, a fail IRC server.
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

require 'failirc/server/errors'
require 'failirc/server/module'
require 'failirc/server/client'

Class.new(IRC::Server::Module) do
    def checkRegistration (type, thing, string)
        if type != :PASS && type != :NICK && type != :USER && !thing.registered?
            thing.send(:numeric, ERR_NOTREGISTERED)
            return false
        end
    end

    def auth (thing, string)
        if  !thing.is_a?(Client)
            return
        end

        thing.password =
    end

    @defaultEvents = {
        :PASS => /^(:[^ ]+ )?PASS /
    }

    @events = {
        :default => checkRegistration,

        :PASS => auth
    }
end
