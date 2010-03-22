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

require 'failirc/extensions'

require 'failirc/server/user'

module IRC

class Server

class Users < ThreadSafeHash
    attr_reader :server, :channel

    def initialize (channel, *args)
        @server  = channel.server
        @channel = channel

        super(*args)
    end

    def server
        @channel.server
    end

    alias __get []

    def [] (user)
        if user.is_a?(Client) || user.is_a?(User)
            user = user.nick
        end

        __get(user)
    end

    alias __set []=

    def []= (user, value)
        if user.is_a?(Client) || user.is_a?(User)
            user = user.nick
        end

        __set(user, value)
    end

    alias __delete delete
    
    def delete (key)
        if key.is_a?(User) || key.is_a?(Client)
            key = key.nick
        end

        key = key.downcase

        user = self[key]

        if user
            __delete(key)

            if channel.empty?
                server.channels.delete(channel)
            end
        end

        return user
    end

    def add (user)
        if user.is_a?(Client)
            self[user.nick] = User.new(user, @channel)
        elsif user.is_a?(User)
            self[user.nick] = user
        else
            raise 'You can only add Client or User.'
        end
    end

    def send (*args)
        each_value {|user|
            user.send(*args)
        }
    end
end

end

end
