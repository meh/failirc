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
require 'resolv'
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

    attr_reader :version, :createdOn, :verbose, :dispatcher, :modules, :channels, :clients, :links, :listening, :config

    alias users clients

    def initialize (conf, verbose)
        @version   = IRC::VERSION
        @createdOn = Time.now
        @verbose   = verbose ? true : false

        @dispatcher = EventDispatcher.new(self)

        @modules = {}

        @channels  = Channels.new(self)
        @clients   = Clients.new(self)
        @links     = Links.new(self)
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

            if klass
                @modules[name] = klass.new(self)
                self.debug "Loaded `#{name}`", ''
            else
                self.debug "Failed to load `#{name}`", ''
            end
        rescue Exception => e
            self.debug(e)
        end
    end

    def host
        @config.elements['config/server/host'].text
    end

    def ip
        begin
            Resolv.getaddress(@config.elements['config/server/host'].text)
        rescue
            return @socket.addr.pop
        end
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
        begin
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
        ensure
            Process.exit!(0)
        end
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

            begin
                connections, = IO::select connections, nil, nil, 2

                if connections
                    connections.each {|socket|    
                        Thread.new {
                            begin
                                string = socket.gets

                                if string
                                    @dispatcher.dispatch :input, things[socket], string.chomp
                                end
                            rescue IOError, Errno::EBADF, Errno::EPIPE
                            rescue Exception => e
                                debug e
                            end
                        }
                    }
                end
            rescue IOError, Errno::EBADF
            rescue Exception => e
                self.debug e
            end
        end
    end

    def kill (thing, message=nil)
        thing.modes[:quitting] = true
        @dispatcher.execute(:kill, thing, message)

        if thing.is_a?(Client)
            if thing.modes[:registered]
                @clients.delete(thing.nick)

                @channels.each_value {|channel|
                    channel.users.delete(thing.nick)
                }
            else
                @clients.delete(thing.socket)
            end
        elsif thing.is_a?(Link)
            @links.delete(thing.host)
        end

        thing.socket.close
    end

    def rehash
        self.config = @configReference
    end

    def config= (reference)
        @config          = Document.new reference
        @configReference = reference

        if !@config.elements['config/server']
            @config.element['config'].add(Element.new('server'))
        end

        if !@config.elements['config/server/name']
            @config.elements['config/server'].add(Element.new('name'))
            @config.elements['config/server/name'].text = "Fail IRC"
        end

        if !@config.elements['config/server/host']
            @config.elements['config/server'].add(Element.new('host'))
            @config.elements['config/server/host'].text = Socket.gethostname.split(/\./).shift
        end

        if !@config.elements['config/server/pingTimeout']
            @config.elements['config/server'].add(Element.new('pingTimeout'))
            @config.elements['config/server/pingTimeout'].text = '60'
        end

        if !@config.elements['config/server/listen']
            @config.elements['config/server'].add(Element.new('listen'))
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

        if !@config.elements['config/messages']
            @config.elements['config'].add(Element.new('messages'))
        end

        if !@config.elements['config/messages/quit']
            @config.elements['config/messages'].add(Element.new('quit'))
            @config.elements['config/messages/quit'].text = 'Quit: '
        end

        @modules.each {|mod|
            mod.finalize
        }

        @modules.clear

        if !@config.elements['config/modules']
            @config.elements['config'].add(Element.new('modules'))
        end

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

    alias to_s host
end

end
