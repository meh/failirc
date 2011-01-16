#--
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
#++

require 'resolv'
require 'nokogiri'

require 'failirc/utils'

require 'failirc/server/clients'
require 'failirc/server/servers'
require 'failirc/server/channels'
require 'failirc/server/dispatcher'

require 'failirc/modules'

module IRC

class Server
  attr_reader :created_on, :dispatcher, :modules, :channels, :config, :data

  def initialize (config)
    @modules    = Modules.new
    @data       = ThreadSafeHash.new
    self.config = config
    @created_on = Time.now
    @dispatcher = Dispatcher.new(self)
    @channels   = Channels.new(self)
  end

  def fire (*args, &block)
    dispatcher.fire(*args, &block)
  end

  def observe (*args, &block)
    dispatcher.observe(*args, &block)
  end

  def connections
    dispatcher.connection.connections
  end

  def clients
    dispatcher.connection.clients
  end

  def servers
    dispatcher.connection.servers
  end

  def host
    @config.xpath('config/server/host').first.text rescue 'localhost'
  end

  def ip
    begin
      Resolv.getaddress(@config.xpath('config/server/host').first.text)
    rescue
      Resolv.getaddress('localhost')
    end
  end

  def name
    @config.xpath('config/server/name').first.text
  end

  def loadModule (name, path=nil, reload=false)
    return if @modules[name.downcase] && !reload

    begin 
      if path
        load "#{path}/#{name}.rb"
      else
        require "#{name}"
      end

      if Module.get.name.downcase == name.downcase
        (@modules[name.downcase] = Module.get).owner = self

        IRC.debug "Loaded `#{name}`."
      else
        raise RuntimeError.new("Module #{name} not found.")
      end
    rescue Exception => e
      IRC.debug "Failed to load `#{name}`."
      IRC.debug e
    end
  end

  def start
    return if @started

    @started = true

    @config.xpath('config/server/listen').each {|listen|
      self.listen(listen, 
        :bind => listen.attributes['bind'],
        :port => listen.attributes['port'],

        :ssl      => listen.attributes['ssl'],
        :ssl_cert => listen.attributes['sslCert'],
        :ssl_key  => listen.attributes['sslKey']
      )
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

  def stopping?
    @stopping
  end

  def listen (*args)
    @dispatcher.connection.listen(*args)
  end

  # kill connection with harpoons on fire
  def kill (thing, message=nil, force=false)
    if !thing || (thing.data[:killing] && (!force || thing.data[:kill_forcing])) || !@dispatcher.connections.exists?(thing.socket)
      return
    end

    if thing.is_a?(User)
      thing = thing.client
    end

    thing.data[:killing] = true

    if force
      thing.data[:kill_forcing] = true

      tmp = @dispatcher.output[thing.socket].drop_while {|item|
        item != :EOC
      }

      @dispatcher.output.clear(thing)
      @dispatcher.output[thing.socket].insert(-1, *tmp)
    end

    @dispatcher.output.push(thing, :EOC)
    @dispatcher.output.push(thing, message)
  end

  # reload the config and modules' configurations
  def rehash
  end

  def config= (dom)
    @config = dom
=begin
    if !@config.elements['config/server']
      @config.elements['config'].add(Element.new('server'))
    end

    if !@config.elements['config/server/name']
      @config.elements['config/server'].add(Element.new('name')).text = 'Fail IRC'
    end

    if !@config.elements['config/server/host']
      @config.elements['config/server'].add(Element.new('host')).text = Socket.gethostname
    end

    if !@config.elements['config/server/timeout']
      @config.elements['config/server'].add(Element.new('timeout')).text = '15'
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

      if !element.attributes['ssl'] || (element.attributes['ssl'] != 'enabled' && element.attributes['ssl'] != 'disabled' && element.attributes['ssl'] != 'promiscuous')
        element.attributes['ssl'] = 'disabled'
      end

      if element.attributes['password'] && element.attributes['password'].match(/:/)
        raise 'Password CANNOT contain :'
      end
    }
=end

    IRC.debug 'Loading modules.'

    @config.xpath('config/modules/module').each {|element|
      if !element['path']
        element['path'] = 'failirc/server/modules'
      end

      self.loadModule element['name'], element['path']
    }

    IRC.debug 'Finished loading modules.'
  end

  alias to_s host
end

end
