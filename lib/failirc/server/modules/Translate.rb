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

class Translate < Module
    def initialize (server)
        @aliases = {
            :input => {
                :TRANSLATE => /^TRANSLATE( |$)/i,
            },
        }

        @events = {
            :custom => {
                :message => Event::Callback.new(self.method(:netlog), -50),
            },

            :input => {
                :TRANSLATE => self.method(:set),
            },
        }

        super(server)
    end

    def translate (chain, from, to, message, level)
        if chain == :input

        elsif chain == :output

        end
    end
end

end

end

end
