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

require 'forwardable'
require 'resolv'
require 'ostruct'

require 'failirc/version'
require 'failirc/utils'
require 'failirc/server/dispatcher'
require 'failirc/modules'

module IRC

class Server
  extend Forwardable

  attr_reader    :created_on, :dispatcher, :modules, :config, :data
  def_delegators :@dispatcher, :dispatch, :register, :fire, :observe, :connections

  def initialize (config)
    @modules    = Modules.new
    @data       = OpenStruct.new
    @created_on = Time.now
    @dispatcher = Dispatcher.new(self)

    self.config = config
  end

  def host
    @config['server']['host'].value rescue 'localhost'
  end

  def ip
    begin
      Resolv.getaddress(host)
    rescue
      Resolv.getaddress('localhost')
    end
  end

  def name
    @config['server']['name'].value rescue 'failirc'
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
        @dispatcher.hook(Module.get)

        Module.get.config = @config.select('/modules/*').find {|mod|
          mod['name'].value.downcase == name.downcase
        }.transform

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

    @config.select('/server/listen/*').each {|listen|
      self.listen({
        'bind' => '0.0.0.0'
      }.merge(listen.transform))
    }

    self.fire(:start, self)

    @dispatcher.start
  end

  def stop
    @stopping = true

    self.fire(:stop, self)

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

  def running?
    @started && !stopping?
  end

  def stopping?
    @stopping
  end

  def listen (*args)
    @dispatcher.connection.listen(*args)
  end

  # kill connection with harpoons on fire
  def kill (thing, message=nil, force=false)
    if !thing || (thing.data.killing && (!force || thing.data.kill_forcing)) || !@dispatcher.connections.exists?(thing.socket)
      return
    end

    if thing.is_a?(User)
      thing = thing.client
    end

    thing.data.killing = true

    if force
      thing.data.kill_forcing = true

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

  def config= (conf)
    @config = conf

    IRC.debug 'Loading modules.'

    @config.select('/modules/*').each {|mod|
      self.loadModule(mod['name'].value, (mod['path'].value rescue 'failirc/server/modules'))
    }

    IRC.debug 'Finished loading modules.'
  end

  alias to_s host
end

end
