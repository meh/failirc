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

Module.define('reupload', '0.0.1') {
  identifier "reupload-#{version};"

  def reupload (url, time=5, service=:imageshack)
    result = url

    begin
      case service
        when :imageshack
          result = timeout time do
            response = Net::HTTP.get_response(URI.parse("http://imageshack.us/transload.php?url=#{URI.escape(url)}"))
            Net::HTTP.get(URI.parse(response['location'])).match(%r{<textarea.*?>(.*?img.*?\..*?)</textarea>})[1] rescue nil
          end
      end
    rescue Timeout::Error
    rescue Exception => e
      IRC.debug e

      result = url
    end

    return result || url
  end

  on message, -102 do |chain=:input, from, to, message|
    return unless chain == :input

    URI.extract(message.clone) {|uri|
      options[:sites].each {|site|
        next unless uri.match(/#{site[:match]}/)

        message.gsub!(/#{Regexp.escape(uri)}/, "#{reupload(uri, (options[:timeout] ? options[:timeout].to_f : 5), (options[:service] || 'imageshack').to_sym)} (#{site[:name]})")
      }
    }
  end
}

end; end
