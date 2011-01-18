#--
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
#++

module IRC; class Server; class Dispatcher; class ConnectionDispatcher

class Things < CaseInsensitiveHash
  def initialize
    @sockets = Hash.new
  end

  alias __get__ []
  alias __set__ []=
  alias __del__ delete

  def [] (what)
    if what.is_a?(String) || what.is_a?(Symbol)
      __get__(what)
    else
      @sockets[what]
    end
  end

  def []= (what, value)
    if what.is_a?(String) || what.is_a?(Symbol) || what.is_a?(Incoming)
      __set__(what.to_s, value)
      @sockets[value.socket] = value
    else
      @sockets[what] = value
    end
  end

  def << (what)
    self[what] = what
  end

  def delete (what)
    if what.is_a?(String) || what.is_a?(Symbol) || what.is_a?(Incoming)
      @sockets.delete(__del__(what.to_s).socket)
    else
      __del__(@sockets.delete(what).to_s)
    end
  end

  def sockets
    @sockets.keys
  end
end

end; end; end; end
