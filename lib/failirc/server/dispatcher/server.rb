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

module IRC; class Server; class Dispatcher

class Server
	attr_reader :server, :options, :signature, :clients

	def initialize (server, options)
		@server  = server
		@options = HashWithIndifferentAccess.new({
			:bind => '0.0.0.0'
		}.merge(options))

		@clients = []
	end

	def method_missing (id, *args, &block)
		@server.__send__ id, *args, &block
	end

	def add (client)
		@clients.push client

		dispatcher.reset!
	end

	def delete (client)
		@clients.delete client

		dispatcher.reset!
	end

	def start
		zelf    = self
		options = @options

		@signature = EM.start_server options[:bind] || '0.0.0.0', options[:port], Client do |client|
			client.instance_eval {
				ssl! if options[:ssl]

				if options[:ssl].is_a? Hash
					start_tls(private_key_file: options[:ssl][:key], cert_chain_file: options[:ssl][:cert])
				else
					start_tls
				end

				@server = zelf
				@server.add client
				@server.fire :connect, client
			}
		end
	end

	def stop
		EM.stop_server @signature
		
		clients = @clients.clear

		dispatcher.reset!
		
		clients.each(&:close_connection_after_writing)
	end

	def ssl?; @options[:ssl];  end
	def bind; @options[:bind]; end
	def port; @options[:port]; end
end

end; end; end
