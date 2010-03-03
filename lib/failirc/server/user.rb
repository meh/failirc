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
    attr_reader :client, :channel, :modes

    def initialize (client, channel, modes=Modes.new)
        @client  = client
        @channel = channel
        @modes   = modes
    end

    def mask
        @client.mask
    end

    def server
        @client.server
    end

    def nick
        @client.nick
    end

    def user
        @client.user
    end

    def host
        @client.host
    end

    def realName
        @client.realName
    end

    def send (type, *args)
        @client.send(type, *args)
    end

    def to_s
        return "#{modes[:level]}#{nick}"
    end

    def inspect
        return "#<User: #{client.inspect} #{channel.inspect} #{modes.inspect}>"
    end
end

end
