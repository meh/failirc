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

class Server < IO
  extend Forwardable

  attr_reader    :dispatcher, :options, :socket, :context, :clients
  def_delegators :@dispatcher, :server

  def initialize (dispatcher, options)
    @dispatcher = dispatcher
    @options    = HashWithIndifferentAccess.new({
      :bind => '0.0.0.0'
    }.merge(options))

    @socket  = TCPServer.new(options[:bind], options[:port])
    @clients = []

    if options[:ssl]
      @context = SSLUtils.context((options[:ssl][:cert] rescue nil), (options[:ssl][:key] rescue nil))
    end

    super(@socket.to_i)
  end

  def ssl?; !!@context;      end
  def host; @options[:bind]; end
  def port; @options[:port]; end

  def accept
    socket = @socket.accept_nonblock

    begin
      host = socket.peeraddr[2]
      ip   = socket.peeraddr[3]
      port = socket.addr[1]

      IRC.debug "#{host}[#{ip}/#{port}] connecting."
    rescue Exception
      IRC.debug "Someone (#{host}[#{ip}/#{port}]) failed to connect."

      return
    end

    server.do {
      begin
        if ssl?
          socket = timeout((self.server.options[:server][:timeout] || 15).to_i) do
            ssl = OpenSSL::SSL::SSLSocket.new(socket, server.context)
            ssl.accept
            ssl
          end
        end

        server.fire :connect, @clients.push(Dispatcher::Client.new(self, socket)).last
        dispatcher.wakeup reset: true
      rescue OpenSSL::SSL::SSLError, Timeout::Error
        socket.write_nonblock "This is an SSL connection, faggot.\r\n" rescue nil
        socket.close

        IRC.debug "#{host}[#{ip}/#{port}] tried to connect to a SSL connection and failed the handshake."
      rescue Errno::ECONNRESET
        socket.close

        IRC.debug "#{host}[#{ip}/#{port}] connection reset."
      rescue Exception => e
        socket.close

        IRC.debug e
      end
    }
  end
end

end; end; end
