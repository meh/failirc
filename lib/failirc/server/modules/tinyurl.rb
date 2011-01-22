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

require 'net/http'
require 'uri'
require 'timeout'

module IRC; class Server

Module.define('tinyurl', '0.0.1') {
  class ::URI::Generic
    def tinyurl (time)
      begin
        content = timeout time do
          Net::HTTP.post_form(URI.parse('http://tinyurl.com/create.php'), { 'url' => self.to_s }).body
        end
            
        content.match('<blockquote><b>(http://tinyurl.com/\w+)</b>')[1] rescue self.to_s
      rescue Timeout::Error
        return self.to_s
      end
    end
  end

  on message, -100 do |chain=:input, from, to, message|
    return unless chain == :input
    
    URI.extract(message.clone) {|uri|
      next if uri.length <= (options[:length] ? options[:length].to_i : 42)

      message.gsub!(/#{Regexp.escape(uri)}/, URI.parse(uri).tinyurl((options[:timeout] ? options[:timeout].to_f : 5)))
    }
  end

  on message, -100 do |chain=:input, from, to, message|
    return unless chain == :output

    if to.value.has_flag?(:tinyurl_preview)
      message.gsub!('http://tinyurl.com', 'http://preview.tinyurl.com')
    end
  end
}

end; end
