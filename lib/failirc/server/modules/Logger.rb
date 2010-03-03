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

require 'failirc/server/module'
require 'failirc/utils'

module IRC

module Modules

class Logger < Module
    include Utils

    def initialize (server)
        @events = {
            :pre  => Event::Callback.new(self.method(:log), -9001),
            :post => Event::Callback.new(self.method(:log), -9001),
        }

        super(server)

        file = @server.config.elements['config/modules/module[@name="TinyURL"]/file']

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

    def log (event, thing, string)
        if (event.chain == :input && event.special == :pre) || (event.chain == :output && event.special == :post)
            @log.puts "[#{Time.now}] #{thing.mask} #{(event.chain == :input) ? '>' : '<'} #{string.inspect}"
            @log.flush
        end
    end
end

end

end
