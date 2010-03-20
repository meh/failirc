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

require 'failirc/server/module'

module IRC

class Server

module Modules

class Firewall < Module
    @@version = '0.0.1'

    def self.version
        return @@version
    end

    def description
        "Firewall-#{Firewall.version}"
    end

    def initialize (server)
        @events = {
            :pre  => Event::Callback.new(self.method(:dispatch), -9001),
            :post => Event::Callback.new(self.method(:dispatch), -9001),

            :custom => {
                :log  => self.method(:log),
                :kill => Event::Callback.new(self.method(:logKill), -9001),
            },
        }

        super(server)
    end

    def rehash
        if @log && @log != $stdout
            @log.close
        end

        file = @server.config.elements['config/modules/module[@name="Firewall"]/file']

        if file
            @log = File.open(file.text)
        else
            @log = $stdout
        end
    end

    def finalize
        if @log != $stdout
            @log.close
        end
    end

    def dispatch (event, thing, string)
        if (event.chain == :input && event.special == :pre) || (event.chain == :output && event.special == :post)
            @log.puts "[#{Time.now}] #{target(thing)} #{(event.chain == :input) ? '>' : '<'} #{string.inspect}"
            @log.flush
        end
    end

    def log (string)
        @log.puts "[#{Time.now}] #{string}"
        @log.flush
    end

    def logKill (thing, message)
        log "#{target(thing)} KILL :#{message}"
    end

    def target (thing)
        if thing.is_a?(Client) || thing.is_a?(User)
            target = "#{thing.nick || '*'}!#{thing.user || '*'}@#{thing.ip || '*'}"
        else
            target = thing.to_s
        end

        return target
    end
end

end

end

end
