#--
# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.doesntexist.org | meh@paranoici.org]
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

require 'forwardable'

require 'failirc/events'
require 'failirc/server/dispatcher/connectiondispatcher'

module IRC; class Server

class Dispatcher
  extend Forwardable

  attr_reader :server, :connection, :event

  def initialize (server)
    @server = server

    @connection = ConnectionDispatcher.new(server)
    @event      = Events.new(server)

    Dispatcher.def_delegators :@event, :hook, :alias, :register, :dispatch, :observe, :fire
    Dispatcher.def_delegators :@connection, :connections, :input, :output, :disconnecting, :wakeup
  end

  def start
    @started = true

    self.loop
  end

  def stop
    if !@started
      return
    end

    @started  = false
    @stopping = true

    @stopping = false
  end

  def loop
    while @started
      begin
        @connection.do
      rescue Exception => e
        IRC.debug e
      end
    end
  end
end

end; end
