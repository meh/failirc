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

require 'failirc/extensions'
require 'failirc/server/clients'
require 'failirc/server/channel'

module IRC

class Channels < ThreadSafeHash
    attr_reader :server

    def initialize (server)
        @server = server

        super()
    end

    alias __delete delete

    def delete (channel)
        if channel.is_a?(Channel)
            __delete(channel.name)
        else
            __delete(channel)
        end
    end

    def add (channel)
        self[channel.name] = channel
    end

    # get single users in the channels
    def unique_users
        result = Clients.new(server)

        each_value {|channel|
            channel.users.each {|nick, user|
                result[nick] = user
            }
        }

        return result
    end

    def inspect
        result = ""

        each_value {|channel|
            result << " ##{channel.name}"
        }

        return result[1, result.length]
    end
end

end
