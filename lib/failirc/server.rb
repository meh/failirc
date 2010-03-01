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
require 'openssl'

require 'rexml/document'
include REXML

require 'failirc'
require 'failirc/server/clients'
require 'failirc/server/links'
require 'failirc/server/channels'
require 'failirc/utils'
require 'failirc/server/errors'
require 'failirc/server/responses'
require 'failirc/server/eventdispatcher'

module IRC

class Server
    include Utils

    attr_reader :verbose, :dispatcher, :modules, :clients, :links, :listening, :config

    alias users clients

    def initialize (conf, verbose)
        @verbose = verbose ? true : false

        @dispatcher = EventDispatcher.new

        @modules = []

        @channels  = Channels.new
        @clients   = Clients.new
        @links     = Links.new
        @listening = []

        self.config = conf
    end

    def loadModule (name, path=nil)
        begin 
            if path[0] == '/'
                $LOAD_PATH.push path
                require name
                $LOAD_PATH.pop
            else
                require "#{path}/#{name}"
            end

            klass = eval("Modules::#{name}")
            @modules.push(klass.new(self))
        rescue Exception => e
            self.debug(e)
        end
    end

    def host
        @config.elements['config'].elements['server'].elements['host'].text
    end

    def start
        if @started
            return
        end

        if !@config
            raise '@config is missing.'
        end

        @listeningThread = Thread.new {
            begin
                @config.elements.each('config/server/listen') {|listen|
                    server = TCPServer.new(listen.attributes['bind'], listen.attributes['port'])

                    if listen.attributes['ssl'] == 'enable'
                        context = OpenSSL::SSL::SSLContext.new
                        context.key = File.read(listen.attributes['sslKey'])
                        context.cert = File.read(listen.attributes['sslCert'])

                        server = OpenSSL::SSL::SSLServer(server, context)
                    end

                    @listening.push({ :socket => server, :listen => listen })
                }
            rescue Exception => e
                self.debug(e)
                Thread.stop
            end

            while true
                begin
                    @listening.each {|server|
                        socket, = server[:socket].accept_nonblock

                        if socket
                            run(socket, server[:listen])
                        end
                    }
                rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
                    IO::select(@listening.map {|server| server[:socket]})
                rescue Exception => e
                    self.debug(e)
                end
            end
        }

        @started = true

        self.loop()
    end

    def stop
        if @started
            @modules.each {|mod|
                mod.finalize
            }

            Thread.kill(@listeningThread)

            @listening.each {|server|
                server[:socket].close
            }

            @clients.each {|key, client|
                client.socket.close
            }

            @links.each {|key, link|
                link.socket.close
            }
        end

        exit 0
    end

    def loop
        while true
            things = @clients.merge(@links)

            if things.empty?
                sleep 1
                next
            end

            connections = things.map {|key, thing|
                things[thing.socket] = thing
                thing.socket
            }

            connections, = IO::select connections, nil, nil, 2

            if connections
                connections.each {|socket|    
                    Thread.new {
                        @dispatcher.do things[socket], socket.gets.chomp
                    }
                }
            end
        end
    end

    def kill (thing)
        if thing.is_a?(Client)
            if thing.registered?
                @clients.delete(thing.nick)

                @channels.each_value {|channel|
                    channel.users.delete(thing.nick)
                }
            else
                @clients.delete(thing.socket)
            end
        elsif thing.is_a?(Link)
            @links.delete(thing.socket)
        end

        thing.socket.close
    end

    def rehash
        self.config = @configReference
    end

    def config= (reference)
        @config          = Document.new reference
        @configReference = reference

        if !@config.elements['config'].elements['server'].elements['name']
            @config.elements['config'].elements['server'].add(Element.new('name'))
            @config.elements['config'].elements['server'].elements['name'].text = "Fail IRC"
        end

        if !@config.elements['config'].elements['server'].elements['host']
            @config.elements['config'].elements['server'].add(Element.new('host'))
            @config.elements['config'].elements['server'].elements['host'].text = Socket.gethostname.split(/\./).shift
        end

        if !@config.elements['config'].elements['server'].elements['listen']
            @config.elements['config'].elements['server'].add(Element.new('listen'))
        end

        @config.elements.each('config/server/listen') {|element|
            if !element.attributes['port']
                element.attributes['port'] = '6667'
            end

            if !element.attributes['bind']
                element.attributes['bind'] = '0.0.0.0'
            end

            if !element.attributes['ssl'] || (element.attributes['ssl'] != 'enable' && element.attributes['ssl'] != 'disable')
                element.attributes['ssl'] = 'disable'
            end
        }

        @modules.each {|mod|
            mod.finalize
        }

        @modules.clear

        @config.elements.each('config/modules/module') {|element|
            if !element.attributes['path']
                element.attributes['path'] = 'failirc/server/modules'
            end

            self.loadModule(element.attributes['name'], element.attributes['path'])
        }
    end

    # Executed with each incoming connection
    def run (socket, listen)
        begin
            @clients[socket] = IRC::Client.new(self, socket, listen)
        rescue Exception => e
            socket.close
            self.debug(e)
        end
    end
end

end
