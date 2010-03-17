# failirc, a fail IRC server.
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
require 'failirc/server/modes'
require 'failirc/server/channels'
require 'failirc/mask'

module IRC

class Client
    include Utils

    attr_reader   :server, :socket, :listen, :channels, :modes, :mask, :nick, :user, :host, :connectedOn
    attr_writer   :quitting
    attr_accessor :password, :ip, :realName

    def initialize (server, socket, listen)
        @server = server
        @socket = socket
        @listen = listen

        @host = socket.peeraddr[2]
        @ip   = socket.peeraddr[3]

        @registered = false

        @channels = Channels.new(@server)
        @modes    = Modes.new

        if listen.attributes['ssl'] == 'enabled'
            @modes[:ssl] = true
        end

        @mask = Mask.new

        @connectedOn = Time.now
    end

    def nick= (value)
        @mask.nick = @nick = value
    end

    def user= (value)
        @mask.user = @user = value
    end

    def host= (value)
        @mask.host = @host = value
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
        raw ":#{server.host} #{'%03d' % response[:code]} #{nick || 'faggot'} #{eval(response[:text])}"
    end

    def to_s
        mask.to_s
    end

    def inspect
        return "#<Client: #{mask} #{modes}#{(modes[:registered]) ? ' registered' : ''}>"
    end
end

end
