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

module IRC

class Client
    attr_reader :version, :verbose, :dispatcher, :servers, :channels

    def initialize (conf, verbose)
        if conf.is_a?(Hash)

        else
            self.config = conf
        end
    end

    def alias (*args)
        dispatcher.alias(*args)
    end

    def register (*args)
        dispatcher.register(*args)
    end

    def rehash
        self.config = @configReference
    end

    def config= (reference)
        @config          = Document.new reference
        @configReference = reference
    end
end

end
