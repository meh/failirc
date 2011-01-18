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

class Data
  attr_reader :server

  def initialize (server)
    @server = server
    @data   = ThreadSafeHash.new
  end

  def [] (socket)
    if socket.is_a?(Client) || socket.is_a?(User) || socket.is_a?(Server)
      socket = socket.socket
    end

    (@data[socket] ||= [])
  end

  def push (socket, string)
    if string == :EOC
      if !socket.is_a?(TCPSocket) && !socket.is_a?(OpenSSL::SSL::SSLSocket)
        socket = socket.socket rescue nil
      end

      if socket
        server.dispatcher.disconnecting.push(:thing => server.dispatcher.connections.things[socket], :output => self[socket])
      end
    else
      string.lstrip!
    end

    server.dispatcher.wakeup

    if (string && !string.empty?) || self[socket].last == :EOC
      self[socket].push(string)
    end
  end

  def pop (socket)
    self[socket].shift
  end

  def clear (socket)
    self[socket].clear
  end

  def delete (socket)
    @data.delete(socket)

    if socket.is_a?(Client) || socket.is_a?(User) || socket.is_a?(Server)
      @data.delete(socket.socket)
    end
  end

  def first (socket)
    self[socket].first
  end

  def last (socket)
    self[socket].last
  end

  def empty? (socket=nil)
    if socket
      if socket.is_a?(Client) || socket.is_a?(User)
        socket = socket.socket
      end

      if @data.has_key?(socket)
         return @data[socket].empty?
      else
        return true
      end
    else
      return @data.all? {|(name, data)|
        data.empty?
      }
    end
  end

  def each (&block)
    @data.each_key &block
  end
end

end; end; end; end
