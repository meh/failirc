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

require 'socket'
require 'timeout'
require 'openssl'

begin
  OpenSSL::SSL::SSLSocket.instance_method :read_nonblock
rescue NameError
  require 'openssl/nonblock'
end

require 'failirc/server/dispatcher/server'
require 'failirc/server/dispatcher/client'

module IRC; class Server

class Dispatcher
  extend Forwardable

  attr_reader :server, :servers

  def initialize (server)
    @server = server

    @servers = []
    @pipes   = IO.pipe
  end

  def start
    @running = true

    self.loop
  end

  def stop
    return unless @running

    @running = false

    wakeup
  end

  def running?
    @running
  end

  def loop
    while running?
      self.do
    end
  end

  def listen (options)
    @servers.push(Dispatcher::Server.new(self, options))

    IRC.debug "Starting listening on #{@servers.last.host}:#{@servers.last.port}#{' (SSL)' if @servers.last.ssl?}"

    wakeup
  end

  def do
    reading, _, erroring = IO.select([@pipes.first] + clients + servers, nil, clients)

    return unless @running or not @clients

    erroring.each {|client|
      client.disconnect 'Input/output error'
    }

    reading.each {|thing|
      case thing
        when Dispatcher::Server then thing.accept
        when Dispatcher::Client then thing.receive
        when IO                 then thing.read_nonblock(2048) rescue nil
      end
    }

    clients.each {|client|
      client.handle
    }
  end

  def clients
    @clients ||= @servers.map {|s|
      s.clients
    }.flatten
  end

  def wakeup (options = {})
    @clients = nil if options[:reset]

    @pipes.last.write '?'
  end
end

end; end
