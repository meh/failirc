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

require 'resolv'

require 'rexml/document'
include REXML

require 'failirc'
require 'failirc/extensions'
require 'failirc/server/clients'
require 'failirc/server/links'
require 'failirc/server/channels'
require 'failirc/utils'
require 'failirc/server/dispatcher'

module IRC

class Server
    include Utils

    attr_reader :version, :createdOn, :verbose, :dispatcher, :modules, :channels, :connections, :config, :data

    def initialize (conf, verbose)
        @version   = IRC::VERSION
        @createdOn = Time.now
        @verbose   = verbose ? true : false

        @dispatcher = Dispatcher.new(self)

        @modules = {}

        @data = ThreadSafeHash.new

        @channels = Channels.new(self)

        self.config = conf
    end

    def clients
        dispatcher.connection.clients
    end

    def links
        dispatcher.connection.links
    end

    def comments
        result = ''

        modules.each_value {|mod|
            begin
                result << " #{mod.description}"
            rescue
            end
        }

        return result[1, result.length]
    end

    def host
        @config.elements['config/server/host'].text
    end

    def ip
        begin
            return Resolv.getaddress(@config.elements['config/server/host'].text)
        rescue
            return Resolv.getaddress('localhost')
        end
    end

    def name
        @config.elements['config/server/name'].text
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

            klass = eval("Modules::#{name}") rescue nil

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

    def start
        if @started
            return
        end

        if !@config
            raise '@config is missing.'
        end

        @config.elements.each('config/server/listen') {|listen|
            @dispatcher.connection.listen({
                :bind => listen.attributes['bind'],
                :port => listen.attributes['port'],

                :ssl      => (listen.attributes['ssl'] == 'enabled'),
                :ssl_cert => listen.attributes['sslCert'],
                :ssl_key  => listen.attributes['sslKey']
            }, listen)
        }

        @started = true

        @dispatcher.start()
    end

    def stop
        @stopping = true

        begin
            dispatcher.stop

            @modules.each {|mod|
                mod.finalize
            }
        ensure
            Process.exit!(0)
        end
    end

    def stopping?
        @stopping
    end

    # kill connection with harpoons on fire
    def kill (thing, message=nil)
        if !thing || thing.modes[:killing] || !@dispatcher.connections.exists?(thing.socket)
            return
        end

        if thing.is_a?(User)
            thing = thing.client
        end

        thing.modes[:killing] = true

        @dispatcher.output.push(thing, :EOC)
        @dispatcher.output.push(thing, message)
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
            @config.elements['config/server/name'].text = 'Fail IRC'
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

            if !element.attributes['ssl'] || (element.attributes['ssl'] != 'enabled' && element.attributes['ssl'] != 'disabled')
                element.attributes['ssl'] = 'disabled'
            end

            if element.attributes['password'] && element.attributes['password'].match(/:/)
                raise 'Password CANNOT contain :'
            end
        }

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
