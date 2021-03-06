# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

version '0.0.1'

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

on :message, priority: -102 do |chain=:input, from, to, message|
	return unless chain == :input

	message.scan(%r{https?://\S+}).uniq.each {|uri|
		options[:matches].each {|name, regex|
			next unless uri.match(/#{regex}/)

			message.gsub!(/#{Regexp.escape(uri)}/, "#{reupload(uri, (options[:timeout] || 5).to_f, (options[:service] || 'imageshack').to_sym)} (#{name})")
		}
	}
end
