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
    attr_reader   :server, :socket, :listen, :registered, :nick, :user, :host, :realName, :state, :channels
    attr_writer   :registered
    attr_accessor :password

    def initialize (server, socket, listen)
        @server = server
        @socket = socket
        @listen = listen

        @registered = false

        @channels = Channels.new
        @state    = {}
    end

    def registered?
        @registered
    end

    def mask
        if !registered?
            return ""
        else
            return "#{nick}!#{user}@#{host}"
        end
    end

    def send (type, *args)
        callback = @@callbacks[type]
        callback(*args)
    end

    @@callbacks = {
        :raw => lambda {|text|
            @socket.puts text
        },

        :numeric => lambda {|response, value|
            server = @server

            send :raw, ":#{server.host} #{'%03d' % response.code} #{nick} #{eval(response.text)}"
        }
    }

    def inspect
        return "<Client: #{(mask.empty?) ? 'nil' : mask}>"
    end
end

end
