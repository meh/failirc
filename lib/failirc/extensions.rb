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

class Reference
    def initialize (name, vars)
        @getter = eval "lambda { #{name} }", vars
        @setter = eval "lambda { |v| #{name} = v }", vars
    end
    
    def value
        @getter.call
    end
    
    def value= (newValue)
        @setter.call(newValue)    
    end
end

def ref (&block)
    Reference.new(block.call, block.binding)
end

class CaseInsensitiveHash < Hash
    def initialize (*args)
        super(*args)
    end

    private

    alias ___set___ []=
    alias ___get___ []
    alias ___delete___ delete

    public

    def []= (key, value)
        if key.class == String
            key = key.downcase
        end

        ___set___(key, value)
    end

    def [] (key)
        if key.class == String
            key = key.downcase
        end
        
        return ___get___(key)
    end

    def delete (key)
        if key.class == String
            key = key.downcase
        end

        ___delete___(key)
    end
end

class ThreadSafeHash < CaseInsensitiveHash
    def initialize (*args)
        @semaphore = Mutex.new

        super(*args)
    end

    private

    alias __set__ []=
    alias __get__ []
    alias __delete__ delete

    public

    def []= (key, value)
        begin
            @semaphore.synchronize {
                return __set__(key, value)
            }
        rescue ThreadError
            return __set__(key, value)
        end
    end

    def [] (key)
        begin
            @semaphore.synchronize {
                return __get__(key)
            }
        rescue ThreadError
            return __get__(key)
        end
    end

    def delete (key)
        begin
            @semaphore.synchronize {
                return __delete__(key)
            }
        rescue ThreadError
            return __delete__(key)
        end
    end
end
