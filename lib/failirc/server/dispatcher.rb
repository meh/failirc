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

require 'failirc/events'
require 'failirc/server/dispatcher/connectiondispatcher'

module IRC; class Server

class Dispatcher
  extend Forwardable

  attr_reader :server, :connection, :event

  def initialize (server)
    @server = server

    @connection = ConnectionDispatcher.new(server)
    @event      = Events.new(server)

    Dispatcher.def_delegators :@event, :alias, :register, :dispatch, :observe, :fire
    Dispatcher.def_delegators :@connection, :connections, :input, :output, :disconnecting

    @intervals = {}
    @timeouts  = {}
  end

  def start
    @started = true

    self.loop
  end

  def stop
    if !@started
      return
    end

    @started  = false
    @stopping = true

    @connection.finalize

    @stopping = false
  end

  def loop
    while true
      begin
        @connection.do
      rescue FiberError
        IRC.debug 'Something went deeply wrong in the dispatcher, aborting.'
        Process::exit 23
      rescue Exception => e
        IRC.debug e
      end

      @intervals.each {|fiber, meta|
        begin
          raise FiberError unless @intervals[fiber]

          if meta[:at] <= Time.now
            fiber.resume

            meta[:at] += meta[:offset]
          end
        rescue FiberError
          clearInterval meta
        rescue Exception => e
          IRC.debug e
        end
      }

      @timeouts.each {|fiber, meta|
        begin
          raise FiberError unless @timeouts[fiber]

          if meta[:at] <= Time.now
            fiber.resume

            clearTimeout meta
          end
        rescue FiberError
          clearTimeout meta
        rescue Exception => e
          IRC.debug e
        end
      }
    end
  end

  def setTimeout (fiber, time)
    @timeouts[fiber] = {
      :fiber => fiber,
      :at  => Time.now + time,
      :on  => Time.now,
    }
  end

  def clearTimeout (timeout)
    @timeouts.delete(timeout[:fiber])
  end

  def setInterval (fiber, time)
    @intervals[fiber] = {
      :fiber  => fiber,
      :offset => time,
      :at   => Time.now + time,
      :on   => Time.now,
    }
  end

  def clearInterval (interval)
    @intervals.delete(interval[:fiber])
  end
end

end; end
