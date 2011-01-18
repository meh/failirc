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

class Connections
  class Server
    attr_reader :socket, :config, :context

    def initialize (socket, config, context)
      @socket  = socket
      @config  = config
      @context = context
    end
  end

  attr_reader :server, :listening, :things

  def initialize (server)
    @server = server

    @listening = []
    @things  = Things.new
  end

  def empty?
    sockets.empty?
  end

  def exists? (socket)
    !!things[socket]
  end

  def delete (socket)
    return unless exists?(socket)

    @things.delete(socket)
  end

  def thing (identifier)
    identifier.is_a?(Incoming) ? identifier : @things[identifier]
  end
end

end; end; end; end
