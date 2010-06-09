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

require 'net/http'
require 'uri'
require 'timeout'

require 'failirc/extensions'
require 'failirc/module'

require 'failirc/server/modules/Base'

module IRC

class Server

module Modules

class Butt < Module
    def initialize (server)
        @events = {
            :custom => {
                :message => Event::Callback.new(self.method(:tinyurl), -100),
            }
        }

        super(server)
    end

    def rehash
        if tmp = @server.config.elements['config/modules/module[@name="Butt"]/length']
            @length = tmp.text.to_i
        else
            @length = 42
        end

        if tmp = @server.config.elements['config/modules/module[@name="Butt"]/timeout']
            @timeout = tmp.text.to_i
        else
            @timeout = 5
        end
    end

    def tinyurl (chain, fromRef, toRef, message, level=nil)
        if chain != :input
            return
        end

        from = fromRef.value
        to   = toRef.value

        URI.extract(message).each {|uri|
            if uri.length <= @length
                next
            end

            if butt = buttify(uri) rescue nil
                message.gsub!(/#{Regexp.escape(uri)}/, butt)
            end
        }
    end

    def buttify (url)
        def escape (string)
            string.gsub(/(.)/) {|match|
                "%#{match.ord.to_s(16)}"
            }  
        end

        begin
            http = Net::HTTP.new('bu.tt', 80)

            response, content = timeout @timeout do
                http.get('/', {})
            end

            options = "authenticity_token=#{escape(content.match(/authenticity_token.*?value="(.*?)"/)[1])}&link[url]=#{escape(url)}&link[account_id]=#{escape(content.match(/link\[account_id\].*value="(.*?)"/)[1])}&link[user_id]=#{escape(content.match(/link\[user_id\].*value="(.*?)"/)[1])}&link[token]="

            headers = {
                'Cookie' => response.response['set-cookie']
            }

            response, content = timeout @timeout do
                http.post('/admin/links/public_create', options, headers)
            end

            headers['Cookie'] = response.response['set-cookie']

            response, content = timeout @timeout do
                http.get('/admin', headers)
            end

            content.match(%r{href=(http://bu.tt/.*?) target='_blank'})[1] rescue nil
        rescue Timeout::Error
            return nil
        rescue Exception => e
            puts $!
            puts e.backtrace.collect.to_a.join("\n")
        end
    end
end

end

end

end
