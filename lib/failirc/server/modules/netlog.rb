# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.doesntexist.org | meh@paranoici.org]
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

require 'uri'

module IRC; class Server

Module.define('netlog', '0.0.1') {
  on message, -101 do |chain=:input, from, to, message|
    URI.extract(message.clone) {|uri|
      if match = uri.match('http://(beta\.)?(\w+?)\.netlog.com.*photo.*?(\d+)')
        country = match[2]
        url     = match[3]
        code    = "000000000#{url}".match(/(\d{3})(\d{3})\d{3}$/)

        message.gsub!(/#{Regexp.escape(uri)}/, "http://#{country}.netlogstatic.com/p/oo/#{code[1]}/#{code[2]}/#{url}.jpg")
      elsif match = uri.match(/netlogstatic/)
        message.gsub!(/#{Regexp.escape(uri)}/, uri.sub(/\/[to]{2}\//, '/oo/'))
      end
    }
  end
}

end; end
