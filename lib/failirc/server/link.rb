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

module IRC

class Server

class Link
    attr_reader :server, :socket, :listen, :host

    def initialize (server, socket, listen)
        @server = server
        @socket = socket
        @listen = listen
    end

    def raw (text)
        @socket.puts text
    end

    def send (type, *args)
        callback = @@callbacks[type]
        callback(args)
    end

    @@callbacks = {
    }
end

end

end
