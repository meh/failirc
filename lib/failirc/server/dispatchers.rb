#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

require 'failirc/server/dispatchers/connections'
require 'failirc/server/dispatchers/events'
require 'failirc/server/dispatchers/workers'

module IRC; class Server

class Dispatchers
  extend Forwardable

  attr_reader    :server, :connections, :events, :workers
  def_delegators :@connections, :servers, :clients
  def_delegator  :@workers, :do, :will_do

  def initialize (server)
    @server = server

    @connections = Connections.new(self)
    @events      = Events.new(self)
    @workers     = Workers.new(self)
  end
end

end; end
