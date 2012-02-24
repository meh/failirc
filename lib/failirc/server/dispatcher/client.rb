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

class Client < EventMachine::Protocols::LineAndTextProtocol
	extend Forwardable

	attr_reader    :server, :ip, :port, :hostname
	attr_accessor  :host
	def_delegators :@server, :dispatcher, :options

	def post_init
		@input  = Queue.new
		@output = Queue.new

		@ip   = Socket.unpack_sockaddr_in(get_peername).last
		@port = Socket.unpack_sockaddr_in(get_sockname).first
		@host = Socket.getnameinfo(get_peername).first

		@hostname = @host

		@data = ''
	end

	def receive_line (line)
		@input.push(line.strip)
		
		server.data_available
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
			server.fire :disconnect, self, \
				case EM.report_connection_error_status(@signature)
				when Errno::ECONNRESET::Errno   then 'Connection reset by peer'
				when Errno::ETIMEDOUT::Errno    then 'Ping timeout'
				when Errno::EHOSTUNREACH::Errno then 'No route to host'
				else 'Client exited'
				end
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

	def ssl!
		return if ssl?

		@ssl = true

		if options[:ssl].is_a? Hash
			start_tls(private_key_file: options[:ssl][:key], cert_chain_file: options[:ssl][:cert])
		else
			start_tls
		end
	end

	def ssl?; @ssl; end
end

end; end
