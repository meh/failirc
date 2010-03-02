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

    def quitting?
        @client.quitting?
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
        @client.username
    end

    def host
        @client.hostname
    end

    def realName
        @client.realName
    end

    def send (type, *args)
        @client.send(type, *args)
    end

    def level
        if modes[:q]
            return '~'
        elsif modes[:a]
            return '&'
        elsif modes[:o]
            return '@'
        elsif modes[:h]
            return '%'
        elsif modes[:v]
            return '+'
        else
            return ''
        end
    end

    def inspect
        return "#{level}#{nick}"
    end
end

end
