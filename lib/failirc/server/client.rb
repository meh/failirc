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

require 'failirc/modes'
require 'failirc/mask'

require 'failirc/server/incoming'
require 'failirc/server/channels'

module IRC

class Server

class Client < Incoming
    attr_reader   :channels, :mask, :nick, :user, :host, :connectedOn
    attr_accessor :password, :realName, :modes

    def initialize (server, socket=nil, config=nil)
        super(server, socket, config)

        @registered = false

        @channels = Channels.new(@server)
        @modes    = Modes.new

        if socket.is_a?(Mask)
            @mask = socket
        else
            @mask     = Mask.new
            self.host = @socket.peeraddr[2]

            if @socket.is_a?(OpenSSL::SSL::SSLSocket)
                @modes[:ssl] = @modes[:z] = true
            end
        end

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

    def numeric (response, value=nil)
        begin
            raw ":#{server.host} #{'%03d' % response[:code]} #{nick} #{eval(response[:text])}"
        rescue Exception => e
            IRC.debug response[:text]
            raise e
        end
    end

    def to_s
        mask.to_s
    end

    def inspect
        "#{mask}[#{ip}/#{port}]"
    end
end

end

end
