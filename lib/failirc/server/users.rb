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

require 'failirc/server/user'

module IRC

class Users < Hash
    attr_reader :channel

    def initialize (channel)
        @channel = channel
    end

    alias __set []=

    def []= (key, value)
        if !value.is_a?(User)
            raise 'You can only set User.'
        end

        __set(key, value)
    end

    alias __delete delete
    
    def delete (key, message=nil)
        if key.is_a?(User) || key.is_a?(Client)
            key = key.nick
        end

        if message.nil?
            message = key
        end

        user = self[key]

        user.server.dispatcher.execute(:user_delete, user, message)

        __delete(key)
    end

    def add (user)
        if !user.is_a?(Client)
            raise 'You can only add Client.'
        end

        self[user.nick] = User.new(user, @channel)

        user.server.dispatcher.execute(:user_add, self[user.nick])
    end

    def inspect (channel=false)
        result = ""

        each_value {|user|
            if channel
                result << " #{user.inspect}"
            else
                result << " #{user.client.inspect}"
            end
        }

        return result[1, result.length]
    end
end

end
