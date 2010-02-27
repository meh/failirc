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
require 'openssl/ssl'
require 'rexml/document'
require 'failirc/server/client'

module IRC

class Server
    def initialize (path)
        config = path

        @clients   = []
        @servers   = []
        @listening = []

        trap "INT" stop
    end

    def start
        include Socket::Constants

        @listeningThread = Thread.new {
            @config.each('config/server/listen') {|listen|
                socket = Socket.new(AF_INET, SOCK_STREAM, 0)
                socket.bind(Socket.sockaddr_in(listen.attributes['port'], listen.attributes['bind']))
                socket.listen(listen.attributes['max'] || 23)

                if listen.attributes['ssl'] == 'enable'
                    socket = OpenSSL::SSL::SSLSocket.new(socket, OpenSSL::SSL::SSLContext.new)
                end

                @listening.push(socket)
            }

            begin
                @listening.each {|socket|
                    socket, = socket.accept_nonblock

                    run(socket)
                }
            rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
                IO::select(@listening)
            end
        } @listeningThread.run
    end

    def stop
        @listeningThread.stop

        @listening.each {|socket|
            socket.close
        }

        @clients.each {|socket|
            socket.close
        }

        @servers.each {|socket|
            socket.close
        }
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
