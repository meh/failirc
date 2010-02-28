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

module IRC

class User
    def initialize (client, modes)
        @client = client
        @modes  = modes
    end

    def send (type, *args)
        @client.server.send(type, client, args)
    end

    def nick
        @client.nick
    end

    def username
        @client.username
    end

    def hostname
        @client.hostname
    end

    def raw (text)
        @socket.puts text
    end

    def send (type, *args)
        callback = @@callbacks[type]
        callback(args)
    end

    @@callbacks = {
        :numeric => lambda {|numeric, message, details|
            raw ":#{server} #{'%03d' % numeric} #{@nick} #{message} :#{details}"
        }
    }
end

end
