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

module IRC

class Client

class Server
    attr_reader :client, :socket, :config, :name, :host, :ip, :port
    attr_accessor :nick, :password

    def initialize (client, socket, config, name=nil)
        @client = client
        @socket = socket
        @config = config

        @host = socket.peeraddr[2]
        @ip   = socket.peeraddr[3]
        @port = socket.addr[1]

        nick = client.nick

        if !name
            name = @host
        else
            if client.server name
                raise Error.new "There is already a server named `#{name}`."
            end
        end

        while client.server name
            name << '_'
        end

        @name = name
    end

    def name= (value)
        if client.server value
            raise Error.new "There is already a server named `#{name}`."
        end

        client.dispatcher.servers[:byName].delete(name)
        client.dispatcher.servers[:byName][value] = self
    end

    def send (symbol, *args)
        begin
            self.method(symbol).call(*args)
        rescue Exception => e
            self.debug e
        end
    end

    def raw (text)
        @client.dispatcher.dispatch :output, self, text
        @client.dispatcher.connection.output.push @socket, text
    end

    def to_s
        name
    end
end

end

end
