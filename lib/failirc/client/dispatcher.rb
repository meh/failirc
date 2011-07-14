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

module IRC; class Client

class Dispatcher
  attr_reader :client

  def initialize (client)
    @client = client

    @servers = []
    @pipes   = IO.pipe
  end

  def start
    @running = true

    self.loop
  end

  def stop
    return unless running?

    @running = false

    wakeup
  end

  def running?
    !!@running
  end

  def loop
    self.do while running?
  end

  def do
    begin
      reading, _, erroring = IO.select([@pipes.first] + servers, nil, servers)
    rescue Errno::EBADF
      return
    end

    return unless running?

    erroring.each {|server|
      server.disconnect 'Input/output error'
    }

    reading.each {|thing|
      case thing
        when Dispatcher::Server then thing.receive
        when IO                 then thing.read_nonblock(2048) rescue nil
      end
    }

    servers.each {|server|
      server.handle
    }
  end

  def wakeup (options = {})
    @pipes.last.write '?'
  end

end

end; end
