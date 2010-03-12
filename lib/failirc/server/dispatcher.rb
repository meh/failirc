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

require 'failirc/server/dispatcher/connectiondispatcher'
require 'failirc/server/dispatcher/eventdispatcher'

module IRC

class Dispatcher
    include Utils

    attr_reader :server, :connection, :event, :aliases, :events

    def initialize (server)
        @server = server

        @connection = ConnectionDispatcher.new(self)
        @event      = EventDispatcher.new(self)
    end

    def start
        @started = true

        @listening = Fiber.new {
            while true
                if @connection.connections.empty?
                    timeout = 2
                else
                    timeout = 0
                end

                @connection.accept timeout

                Fiber.yield
            end
        }

        @reading = Fiber.new {
            while true
                @connection.read

                Fiber.yield
            end
        }

        @handling = Fiber.new {
            while true
                @connection.handle

                Fiber.yield
            end
        }

        @writing = Fiber.new {
            while true
                @connection.write

                Fiber.yield
            end
        }
        
        self.loop
    end

    def stop
        if !@started
            return
        end

        @started  = false
        @stopping = true

        @event.finalize
        @connection.finalize

        @stopping = false
    end

    def loop
        while true
            [@listening, @reading, @handling, @writing].each {|fiber|
                begin
                    fiber.resume
                rescue Exception => e
                    self.debug e
                end
            }
        end
    end

    def connections
        @connection.connections
    end

    def input
        @connection.input
    end

    def output
        @connection.output
    end

    def alias (*args)
        @event.alias(*args)
    end

    def register (*args)
        @event.register(*args)
    end

    def dispatch (*args)
        @event.dispatch(*args)
    end

    def execute (*args)
        @event.execute(*args)
    end
end

end
