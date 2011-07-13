#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

require 'failirc/common/utils'
require 'failirc/common/events'
require 'failirc/common/workers'
require 'failirc/common/modules'
require 'failirc/common/modes'

require 'failirc/server/dispatcher'

module IRC

class Server
  extend Forwardable

  attr_reader :options, :dispatcher

  def_delegators :@dispatcher, :listen
  def_delegators :@events, :register, :dispatch, :observe, :fire, :hook
  def_delegators :@workers, :do
  def_delegators :@modules, :load

  def initialize (options={})
    @options = HashWithIndifferentAccess.new(options)

    @dispatcher = Dispatcher.new(self)
    @events     = Events.new(self)
    @workers    = Workers.new(self)
    @modules    = Modules.new(self, '/failirc/server/modules')

    if (@options[:server][:listen] rescue nil)
      @options[:server][:listen].each {|data|
        listen(data)
      }
    end

    if @options[:modules]
      @options[:modules].each {|name, data|
        begin
          mod = @modules.load(name, data)

          if mod
            hook mod

            IRC.debug "#{name} loaded"
          else
            IRC.debug "#{name} had some errors"
          end
        rescue LoadError
          IRC.debug "#{name} not found"
        end
      }
    end
  end
  
  def start
    fire :start, self

    @dispatcher.start
  end

  def stop
    fire :stop, self

    @dispatcher.stop
  end

  def host
    @options[:server][:host] || 'localhost'
  end

  def ip
    begin
      Resolv.getaddress(host)
    rescue
      Resolv.getaddress('localhost')
    end
  end

  def name
    @options[:server][:name] || 'failirc'
  end
end

end
