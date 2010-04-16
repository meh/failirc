# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.doesntexist.org | meh.ffff@gmail.com]
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

require 'failirc/utils'

class Incoming
    attr_reader :server, :socket, :config, :ip, :port, :data

    def initialize (server, socket=nil, config=nil)
        if server.is_a?(Incoming)
            tmp = server

            @server = tmp.server
            @socket = tmp.socket
            @config = tmp.config
            @data   = tmp.data
        else
            @server = server
            @socket = socket
            @config = config
            @data   = {}
        end

        @ip   = @socket.peeraddr[3] rescue nil
        @port = @socket.addr[1] rescue nil
    end

    def send (symbol, *args)
        begin
            self.method(symbol).call(*args)
        rescue Exception => e
            self.debug e
        end
    end

    def raw (text)
        @server.dispatcher.dispatch :output, self, text
        @server.dispatcher.connection.output.push @socket, text
    end

    def numeric (response, value=nil)
        begin
            raw ":#{server.host} #{'%03d' % response[:code]} faggot #{eval(response[:text])}"
        rescue Exception => e
            self.debug response[:text]
            raise e
        end
    end

    def to_s
        "#{@ip}[#{@port}]"
    end

    def inspect
        to_s
    end
end
