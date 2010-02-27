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

require 'socket'
require 'rexml/document'
require 'failirc/server/client'

module IRC

class Server
    def initialize (path)
        config = path

        @clients = []
        @servers = []
    end

    def start
        
    end

    def rehash
        config = @config.path
    end

    def config= (path)
        @config      = Document.new File.new(path)
        @config.path = path

        if !defined? @config.name
            @config.name = "Fail IRC"
        end

        if !defined? @config.bind
            @config.bind = "0.0.0.0"
        end
    end

    # Executed with each incoming connection
    def run (socket)
        begin
            @clients.push(IRC::Client.new(self, socket))
        rescue
            socket.puts $!
            socket.close
        end
    end
end

end
