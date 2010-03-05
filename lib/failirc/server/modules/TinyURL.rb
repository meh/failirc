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

require 'failirc/extensions'
require 'failirc/server/module'
require 'net/http'
require 'uri'

module IRC

module Modules

class TinyURL < Module
    def initialize (server)
        @events = {
            :custom => {
                :message => Event::Callback.new(self.method(:tinyurl), -9001),
            }
        }

        super(server)
    end

    def rehash
        @length = @server.config.elements['config/modules/module[@name="TinyURL"]/length']

        if @length
            @length = @length.text.to_i
        else
            @length = 42
        end
    end

    def tinyurl (sender, receiver, message)
        URI.extract(message).each {|uri|
            if uri.length > @length
                tiny = tinyurlify(uri)

                if tiny
                    message.gsub!(/#{Regexp.escape(uri)}/, tiny)
                end
            end
        }
    end

    def tinyurlify (url)
        content = Net::HTTP.post_form(URI.parse('http://tinyurl.com/create.php'), { 'url' => url }).body
        match   = content.match(/<blockquote><b>(http:\/\/tinyurl.com\/\w+)<\/b>/)

        if match
            return match[1]
        end
    end
end

end

end
