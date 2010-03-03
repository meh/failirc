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

require 'thread'
require 'failirc/server/channel'

module IRC

class Channels < Hash
    attr_reader :server

    def initialize (server)
        @server = server

        @semaphore = Mutex.new

        super()
    end

    alias __set []=

    def []= (key, value)
        if !value.is_a?(Channel)
            raise 'You can only set a Channel'
        end

        @semaphore.synchronize {
            __set(key, value)
        }
    end

    alias __get []
        
    def [] (key)
        @semaphore.synchronize {
            return __get(key)
        }
    end

    alias __delete delete

    def delete (key)
        @semaphore.synchronize {
            __delete key
        }
    end

    # get single users in the channels
    def users
        result = {}

        each_value {|channel|
            channel.users.each {|nick, user|
                result[nick] = user
            }
        }

        return result
    end

    def add (channel)
        self[channel.name] = channel
    end

    def clean
        each {|name, channel|
            puts channel.empty?.inspect

            if channel.empty?
                delete(name)
            end
        }
    end

    def inspect (user=nil)
        result = ""

        each_value {|channel|
            if user
                result << " #{channel.users.select(user).levels.sort.first}##{channel.name}"
            else 
                result << " ##{channel.name}"
            end
        }

        return result[1, result.length]
    end
end

end
