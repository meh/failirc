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

require 'resolv'

require 'rexml/document'
include REXML

require 'failirc'
require 'failirc/utils'

require 'failirc/client/dispatcher'

module IRC

class Client
    attr_reader :version, :verbose, :config, :modules, :dispatcher, :servers, :channels

    def initialize (conf, verbose)
        @version = IRC::VERSION
        @verbose = verbose

        @modules = {}

        @dispatcher = Dispatcher.new self

        self.config = conf
    end

    def loadModule (name, path=nil, reload=false)
        if @modules[name] && !reload
            return
        end

        begin 
            if path[0] == '/'
                $LOAD_PATH.push path
                require name
                $LOAD_PATH.pop
            else
                require "#{path}/#{name}"
            end

            klass = eval("Modules::#{name}") rescue nil

            if klass
                @modules[name] = klass.new(self)
                self.debug "Loaded `#{name}`."
            else
                raise Exception
            end
        rescue Exception => e
            self.debug "Failed to load `#{name}`."
            self.debug e
        end
    end

    def start
        if @started
            return
        end

        if !@config
            raise 'config is missing'
        end

        @started = true

        @config.elements.each('config/servers/server') {|element|
            self.connect({
                :host => element.attributes['host'],
                :port => element.attributes['port'],

                :ssl      => element.attributes['ssl'],
                :ssl_cert => element.attributes['sslCert'],
                :ssl_key  => element.attributes['sslKey']
            }, element)
        }

        @dispatcher.start
    end

    def stop
        @stopping = true

        begin
            dispatcher.stop

            @modules.each {|mod|
                mod.finalize
            }
        rescue
        end

        @stopping = false
        @started  = false
    end

    def connect (*args)
        @dispatcher.connection.connect(*args)
    end

    def server (identifier)
        dispatcher.server identifier
    end

    def alias (*args)
        dispatcher.alias(*args)
    end

    def register (*args)
        dispatcher.register(*args)
    end

    def nick
        @config.elements['config/informations/nick'].text
    end

    def user
        @config.elements['config/informations/user'].text
    end

    def realName
        @config.elements['config/informations/realName'].text
    end

    def execute (*args)
        @dispatcher.execute(*args)
    end

    def rehash
        self.config = @configReference
    end

    def config= (reference)
        if reference.is_a?(Hash)
            @config = Document.new

            @config.add Element.new 'config'
            @config.elements['config'].add Element.new 'informations'
            @config.elements['config'].add Element.new 'servers'
            @config.elements['config'].add Element.new 'modules'

            informations = @config.elements['config/informations']

            informations.add(Element.new 'nick').text     = reference[:nick] || 'fail'
            informations.add(Element.new 'user').text     = reference[:user] || 'fail'
            informations.add(Element.new 'realName').text = reference[:realName] || "failirc-#{version}"

            servers = @config.element['config/servers']

            if reference[:servers]
                reference[:servers].each {|server|
                    element = servers.add(Element.new 'server')

                    element.attributes['host']    = server[:host]
                    element.attributes['port']    = server[:port]
                    element.attributes['ssl']     = server[:ssl] || 'disabled'
                    element.attributes['sslCert'] = server[:ssl_cert]
                    element.attributes['sslKey']  = server[:ssl_key]
                }
            end

            modules = @config.elements['config/modules']

            if reference[:modules]
                reference[:modules].each {|mod|
                    element = modules.add(Element.new 'module')

                    element.attributes['name'] = mod[:name]
                }
            end
        else
            @config = Document.new reference
        end

        @configReference = reference

        if !@config.elements['config/servers']
            @config.elements['config'].add Element.new 'servers'
        end

        @config.elements.each('config/servers/server') {|server|
            if !server.attributes['ssl']
                server.attributes['ssl'] = 'disabled'
            end
        }

        self.debug 'Loading modules.'

        @config.elements.each('config/modules/module') {|element|
            if !element.attributes['path']
                element.attributes['path'] = 'failirc/client/modules'
            end

            self.loadModule element.attributes['name'], element.attributes['path']
        }

        self.debug 'Finished loading modules.', "\n"
    end
end

end
