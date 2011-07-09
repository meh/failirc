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

require 'failirc/server/dispatchers/connections/server'

module IRC; class Server; class Dispatchers

class Connections < Dispatcher
  attr_reader :servers

  def initialize (parent)
    super

    @servers = []
    @pipes   = IO.pipe
  end

  def listen (options)
    @servers.push(Connections::Server.new(self, options))

    wakeup
  end

  def do
    begin
      reading, writing, erroring = IO.select([@pipes.first] + clients + servers)
    rescue; ensure
      clean
    end

    erroring.each {|thing|
      case thing
        when Connections::Server then servers.delete(thing)
        when Connections::Client then thing.kill 'Input/output error', :force => true
        when IO                  then @pipes = IO.pipe
      end
    }

    reading.each {|thing|
      case thing
        when Connections::Server then thing.accept
        when Connections::Client then thing.receive
        when IO                  then thing.read_nonblock(2048) rescue nil
      end
    }

    @clients.each {|client|
      client.handle
    }

    writing.each {|thing|
      case thing
        when Connections::Client then thing.flush
      end
    }
  end

  def clients
    @clients ||= @servers.map {|s|
      s.clients
    }.flatten
  end

  def wakeup (options)
    @clients = nil if options[:reset]

    @pipes.last.write '?'
  end
end

end; end; end
