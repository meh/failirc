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

module IRC; class Server

class Client < EM::Connection
	extend Forwardable

	attr_reader    :server, :ip, :port, :input, :output
	attr_accessor  :host
	def_delegators :@server, :dispatcher, :options

	def post_init
		@input  = Queue.new
		@output = Queue.new

		@ip   = Socket.unpack_sockaddr_in(get_peername).last
		@port = Socket.unpack_sockaddr_in(get_sockname).first
		@host = @ip

		@data = ''
	end

	def receive_data (data)
		@data << data

		return unless @data.include? "\n"

		@data.lines.each {|line|
			@data = line and break unless line.include? "\n"

			@input.push(line.strip)
		}

		@data.clear if @data.include? "\n"

		unless @input.empty?
			server.data_available
		end
	end

	def send_message (message)
		server.dispatch :output, self, message

		@output.push message

		flush! unless handling?
	end

	def disconnect (message)
		server.fire :disconnect, self, message

		@disconnected = true

		close_connection_after_writing
	end

	def unbind
		@server.delete(self)

		unless @disconnected
			server.fire :disconnect, self, 'Client exited'
		end
	end

	def handling?; @handling;         end
	def handling!; @handling = true;  end
	def handled!;  @handling = false; end

	def handle
		return true if handling?

		if @input.empty?
			flush!

			return false
		end

		handling!

		EM.defer -> {
			begin
				server.dispatch :input, self, @input.pop
			rescue Exception => e
				IRC.debug e
			end
		}, -> status {
			flush!

			handled!
		}

		true
	end

	def flush!
		until @output.empty?
			send_data "#{@output.pop}\r\n"
		end
	end

	alias to_s ip

	def ssl?
		false
	end
end

class SSLClient < Client
	def post_init
		start_tls

		super
	end

	def ssl?
		true
	end
end

end; end
