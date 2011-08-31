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

class Client < IO
  extend Forwardable

  attr_reader    :connected_to, :socket, :ip, :host, :port
  def_delegators :@connected_to, :server, :dispatcher, :options

  def initialize (connected_to, socket)
    @connected_to = connected_to
    @socket       = socket

    @input  = Queue.new
    @output = Queue.new

    @ip   = @socket.peeraddr[3] rescue nil
    @host = @socket.peeraddr[2] rescue nil
    @port = @socket.addr[1]     rescue nil

    super(@socket.to_i)
  end

  def ssl?
    socket.is_a?(OpenSSL::SSL::SSLSocket)
  end

  def receive
    return if disconnected?

    begin
      input = ''

      begin; loop do
        input << @socket.read_nonblock(4096)
      end; rescue Errno::EAGAIN, IO::WaitReadable; end

      raise Errno::EPIPE if input.empty?

      input.split(/[\r\n]+/).each {|string|
        @input.push(string)
      }
    rescue IOError
      disconnect 'Input/output error'
    rescue Errno::EBADF, Errno::EPIPE, OpenSSL::SSL::SSLError
      disconnect 'Client exited'
    rescue Errno::ECONNRESET
      disconnect 'Connection reset by peer'
    rescue Errno::ETIMEDOUT
      disconnect 'Ping timeout'
    rescue Errno::EHOSTUNREACH
      disconnect 'No route to host'
    rescue Exception => e
      IRC.debug e
    end
  end; alias recv receive

  def send (message)
    return if disconnected?(true)

    dispatcher.server.dispatch :output, self, message
    @output.push(message)

    flush
  end

  def flush
    return if @output.empty? or disconnected?(true)

    begin
      @socket.write_nonblock("#{@last}\r\n") if @last

      until @output.empty?
        @last = @output.pop
        @last.force_encoding 'ASCII-8BIT'

        @socket.write_nonblock("#{@last}\r\n")
      end

      @last = nil
    rescue IOError
      disconnect 'Input/output error'
    rescue Errno::EBADF, Errno::EPIPE, OpenSSL::SSL::SSLError
      disconnect 'Client exited'
    rescue Errno::ECONNRESET
      disconnect 'Connection reset by peer'
    rescue Errno::ETIMEDOUT
      disconnect 'Ping timeout'
    rescue Errno::EHOSTUNREACH
      disconnect 'No route to host'
    rescue Errno::EAGAIN, IO::WaitWritable
    rescue Exception => e
      IRC.debug e
    end
  end

  def handle
    return if disconnected?(true) or @handling or @input.empty?

    @handling = true

    server.do {
      begin
        server.dispatch :input, self, @input.pop
      rescue Exception => e
        IRC.debug e
      end

      @handling = false

      dispatcher.wakeup unless @input.empty?
    }
  end

  def disconnect (message, options={})
    return if disconnected? and @told

    @told = true

    server.fire :disconnect, self, message

    IRC.debug "#{self} disconnecting because: #{message}"

    connected_to.clients.delete(self)
    dispatcher.wakeup reset: true

    begin
      flush
    rescue; ensure
      @socket.close rescue nil
    end
  end

  def disconnected? (real=false)
    return true if @told and not real

    begin
      @socket.closed?
    rescue Exception
      true
    end
  end

  def to_s
    "#{host}"
  end
end

end; end; end
