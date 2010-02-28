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

require 'failirc/utils'
require 'failirc/server/channels'

module IRC

class Client
    attr_reader :server, :socket, :nick, :user, :host, :realName, :state, :channels

    def initialize (server, socket)
        @server = server
        @socket = socket

        @nick     = nick
        @user     = username
        @host     = hostname
        @realName = realname

        @channels = Channels.new
        @state    = {}
    end

    def raw (text)
        @socket.puts text
    end

    def send (type, *args)
        callback = @@callbacks[type]
        callback(args)
    end

    @@callbacks = {
        :numeric => lambda {|response, result, value|
            server = @server

            raw ":#{server.host} #{'%03d' % response.code} #{nick} #{eval(response.text)}"
        }
    }
end

end
