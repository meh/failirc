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

require 'thread'
require 'socket'
require 'openssl/ssl'
require 'rexml/document'

require 'failirc'
require 'failirc/server/client'
require 'failirc/utils'

module IRC

require 'failirc/server/errors'
require 'failirc/server/responses'

class Server
    def initialize (conf)
        config = conf

        @clients   = []
        @servers   = []
        @listening = []

        trap "INT", stop
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
        }

        @pingThread = Thread.new {
            while true
                sleep 60

                send :ping
            end
        }
        
        @listeningThread.run
        @pingThread.run
    end

    def stop
        @listeningThread.stop
        @pingThread.stop

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
        config = @config.reference
    end

    def config= (conf)
        include REXML

        @config           = Document.new conf
        @config.reference = reference

        if !@config.elements['config'].elements['server'].elements['name']
            @config.elements['config'].elements['server'].add(Element.new('name'))
            @config.elements['config'].elements['server'].elements['name'].text = "Fail IRC"
        end

        if !@config.elements['config'].elements['server'].elements['listen']
            @config.elements['config'].elements['server'].add(Element.new('listen'))
        end

        @config.elements.each("config/server/listen") {|element|
            if !element.attributes['port']
                element.attributes['port'] = '6667'
            end

            if !element.attributes['bind']
                element.attributes['bind'] = '0.0.0.0'
            end

            if !element.attributes['ssl'] || (element.attributes['ssl'] != 'enable' && element.attributs['ssl'] != 'disable')
                element.attributes['ssl'] = 'disable'
            end
        }
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

    def send (type, *args)
        callback = @@callbacks[type]
        callback(args)
    end

    @@callbacks = {
        :ping => lambda {
            puts "lol"
        }
    }
end

end
