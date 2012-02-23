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

require 'failirc/server/dispatcher/server'
require 'failirc/server/dispatcher/client'

module IRC; class Server

class Dispatcher
	attr_reader :server, :listens_on

	def initialize (server)
		@server = server

		@listens_on = []
	end

	def reset!
		@clients = nil
	end

	def clients
		@clients ||= @listens_on.reduce([]) {|result, server|
			result.concat(server.clients)
		}
	end

	def running?; @running; end

	def start
		@running = true

		@listens_on.each {|server|
			server.start
		}
	end

	def stop
		@listens_on.each {|server|
			server.stop
		}
	end

	def data_available
		return if @working

		@working = true

		EM.next_tick {
			if clients.any? { |c| c.handle }
				EM.next_tick {
					data_available
				}
			end

			@working = false
		}
	end

	def listen (options)
		server = Server.new(@server, options)

		@listens_on.push server

		IRC.debug "Starting listening on #{server.host}:#{server.port}#{' (SSL)' if server.ssl?}"

		if running?
			EM.schedule {
				server.start
			}
		end
	end

	def set_timeout (*args, &block)
		EM.schedule {
			EM.add_timer(*args, &block)
		}
	end

	def set_interval (*args, &block)
		EM.schedule {
			EM.add_periodic_timer(*args, &block)
		}
	end

	def clear_timeout (what)
		EM.schedule {
			EM.cancel_timer(what)
		}
	end

	alias clear_interval clear_timeout
end

end; end
