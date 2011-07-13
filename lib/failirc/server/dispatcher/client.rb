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

  attr_reader    :connected_to, :socket, :ip, :host, :port, :data
  def_delegators :@connected_to, :server, :dispatcher, :options

  def initialize (connected_to, socket)
    @connected_to = connected_to
    @socket       = socket

    @input  = Queue.new
    @output = Queue.new

    @ip   = @socket.peeraddr[3] rescue nil
    @host = @socket.peeraddr[2] rescue nil
    @port = @socket.addr[1]     rescue nil

    @data = InsensitiveStruct.new

    super(@socket.to_i)
  end

  def ssl?
    socket.is_a?(OpenSSL::SSL::SSLSocket)
  end

  def receive
    ap disconnected? or killed?

    return if disconnected? or killed?

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
      kill 'Input/output error', :force => true
    rescue Errno::EBADF, Errno::EPIPE, OpenSSL::SSL::SSLError
      kill 'Client exited', :force => true
    rescue Errno::ECONNRESET
      kill 'Connection reset by peer', :force => true
    rescue Errno::ETIMEDOUT
      kill 'Ping timeout', :force => true
    rescue Errno::EHOSTUNREACH
      kill 'No route to host', :force => true
    rescue Exception => e
      IRC.debug e
    end
  end; alias recv receive

  def send (message)
    dispatcher.server.dispatch :output, self, message

    @output.push(message)
  end

  def flush
    return if @output.empty?

    begin
      @socket.write_nonblock("#{@last}\r\n") if @last

      until @output.empty?
        @last = @output.pop
        @last.force_encoding 'ASCII-8BIT'

        @socket.write_nonblock("#{@last}\r\n")
      end

      @last = nil
    rescue IOError
      kill 'Input/output error', :force => true
    rescue Errno::EBADF, Errno::EPIPE, OpenSSL::SSL::SSLError
      kill 'Client exited', :force => true
    rescue Errno::ECONNRESET
      kill 'Connection reset by peer', :force => true
    rescue Errno::ETIMEDOUT
      kill 'Ping timeout', :force => true
    rescue Errno::EHOSTUNREACH
      kill 'No route to host', :force => true
    rescue Errno::EAGAIN, IO::WaitWritable
    rescue Exception => e
      IRC.debug e
    end
  end

  def handle
    return if @handling or @input.empty?

    @handling = true

    server.do {
      begin
        server.dispatch :input, self, @input.pop

        flush
      rescue Exception => e
        IRC.debug e
      end

      @handling = false

      dispatcher.wakeup unless @input.empty?
    }
  end

  def kill (message, options={})
    return if killed? and !options[:force]

    @killed = true

    server.fire :kill,
  end

  def killed?
    !!@killed
  end

  def disconnected?
    @socket.closed?
  end
end

end; end; end
