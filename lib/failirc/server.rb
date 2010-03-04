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
require 'failirc/extensions'
require 'failirc/server/clients'
require 'failirc/server/links'
require 'failirc/server/channels'
require 'failirc/utils'
require 'failirc/server/errors'
require 'failirc/server/responses'
require 'failirc/server/dispatcher'

module IRC

class Server
    include Utils

    class Connections < ::Hash
        attr_reader :server

        def initialize (server)
            @server = server

            super()

            self[:listening] = {
                :sockets => [],
                :servers => {},
            }

            self[:sockets] = []
            self[:things]  = {}
            self[:clients] = {}
            self[:links]   = {}
        end

        def empty?
            self[:sockets].empty?
        end

        def exists? (socket)
            self[:things][socket] ? true : false
        end

        alias __delete delete

        def delete (socket)
            thing = self[:things][socket]

            if thing.is_a?(Client)
                self[:clients].delete(thing.nick)
                self[:clients].delete(socket)
            elsif thing.is_a?(Link)
                self[:links].delete(thing.host)
                self[:links].delete(socket)
            end

            self[:sockets].delete(socket)
            self[:things].delete(socket)

            socket.close rescue IOError
        end
    end

    attr_reader :version, :createdOn, :verbose, :dispatcher, :modules, :channels, :connections, :config

    def initialize (conf, verbose)
        @version   = IRC::VERSION
        @createdOn = Time.now
        @verbose   = verbose ? true : false

        @dispatcher = Dispatcher.new(self)

        @modules = {}

        @connections = Connections.new(self)
        @channels    = Channels.new(self)

        @killing = Hash.new

        self.config = conf
    end

    def clients
        @connections[:clients]
    end

    def links
        @connections[:links]
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

            begin
                klass = eval("Modules::#{name}")
            rescue
            end

            if klass
                @modules[name] = klass.new(self)
                self.debug "Loaded `#{name}`.", nil
            else
                self.debug "Failed to load `#{name}`.", nil
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

                    @connections[:listening][:sockets].push(server)
                    @connections[:listening][:servers][server] = listen
                }
            rescue Exception => e
                self.debug(e)
                Thread.stop
            end

            while true
                begin
                    @connections[:listening][:sockets].each {|server|
                        socket, = server.accept_nonblock

                        if socket
                            run socket, @connections[:listening][:servers][server]
                        end
                    }
                rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
                    IO::select(@connections[:listening][:sockets])
                rescue Exception => e
                    self.debug e
                end
            end
        }

        @started = true

        @dispatcher.loop()
    end

    def stop
        @stopping = true

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
                    kill client, 'Good night sweet prince.'
                }

                @links.each {|key, link|
                    kill client, 'Good night sweet prince.'
                }
            end
        ensure
            Process.exit!(0)
        end
    end

    def stopping?
        @stopping
    end

    # Executed with each incoming connection
    def run (socket, listen)
        # here, somehow we should check if the incoming peer is a linked server or a real client

        begin
            @connections[:sockets].push(socket)
            @connections[:things][socket]  = @connections[:clients][socket] = IRC::Client.new(self, socket, listen)
        rescue Exception => e
            socket.close
            self.debug(e)
        end
    end

    # kill connection with harpoons on fire
    def kill (thing, message=nil)
        if @killing[thing] || !@connections.exists?(thing.socket)
            return
        end

        if thing.is_a?(User)
            thing = thing.client
        end

        @killing[thing] = true

        @dispatcher.execute(:kill, thing, message)

        if thing.is_a?(Client)
            thing.modes[:quitting] = true

            if thing.modes[:registered]
                @channels.each_value {|channel|
                    channel.users.delete(thing.nick)
                }
            end
        elsif thing.is_a?(Link)
            # wat
        end

        @connections.delete(thing.socket)

        @killing.delete(thing)
    end

    # reload the config and modules' configurations
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
            @config.elements['config/server/host'].text = Socket.gethostname
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

        if !@config.elements['config/modules']
            @config.elements['config'].add(Element.new('modules'))
        end

        @modules.each_value {|mod|
            mod.rehash
        }

        self.debug 'Loading modules.', nil

        @config.elements.each('config/modules/module') {|element|
            if !element.attributes['path']
                element.attributes['path'] = 'failirc/server/modules'
            end

            if !@modules[element.attributes['name']]
                self.loadModule(element.attributes['name'], element.attributes['path'])
            end
        }

        self.debug 'Finished loading modules.'
    end

    alias to_s host
end

end
