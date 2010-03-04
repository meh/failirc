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

module IRC

class Hash < ::Hash
    def initialize (*args)
        @semaphore = Mutex.new

        super(*args)
    end

    private

    alias __set []=
    alias __get []
    alias __delete delete

    public

    def []= (key, value)
        if key.class == String
            key = key.downcase
        end

        begin
            @semaphore.synchronize {
                return __set(key, value)
            }
        rescue ThreadError
            return __set(key, value)
        end
    end

    def [] (key)
        if key.class == String
            key = key.downcase
        end

        begin
            @semaphore.synchronize {
                return __get(key)
            }
        rescue ThreadError
            return __get(key)
        end
    end

    def delete (key)
        if key.class == String
            key = key.downcase
        end

        begin
            @semaphore.synchronize {
                return __delete(key)
            }
        rescue ThreadError
            return __delete(key)
        end
    end
end

end
