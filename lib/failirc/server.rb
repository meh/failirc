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

require 'failirc/common/utils'
require 'failirc/common/events'
require 'failirc/common/workers'

require 'failirc/server/dispatcher'

module IRC

class Server
  extend Forwardable

  attr_reader :options, :dispatcher

  def_delegators :@dispatcher, :start, :stop
  def_delegators :@events, :register, :dispatch, :observe, :fire
  def_delegators :@workers, :do

  def initialize (options={})
    @options = options

    @dispatcher = Dispatcher.new(self)
    @events     = Events.new(self)
    @workers    = Workers.new(self)
  end

  def server; self; end
end

end
