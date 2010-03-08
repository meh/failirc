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

module IRC

module Modules

class Netlog < Module
    def initialize (server)
        @events = {
            :custom => {
                :message => Event::Callback.new(self.method(:netlog), -9002),
            }
        }

        super(server)
    end

    def netlog (sender, receiver, message)
        URI.extract(message).each {|uri|
            match = uri.match('http://(\w+?)\.netlog.com.*?photo.*?(\d+)');

            if match
                country = match[1]
                url     = match[2]
                code    = "000000000#{url}".match(/(\d{3})(\d{3})\d{3}$/)

                message.gsub!(/#{Regexp.escape(uri)}/, "http://#{country}.netlogstatic.com/p/oo/#{code[1]}/#{code[2]}/#{url}.jpg")
            end
        }
    end
end

end

end
