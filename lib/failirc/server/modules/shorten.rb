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

require 'shortie'

version    '0.0.1'
identifier 'shorten'

class Shortie::Service
	singleton_memoize :find_by_key
end

on :message, priority: -100 do |chain=:input, from, to, message|
	return unless chain == :input

	message.scan(%r{https?://\S+}).uniq.each {|uri|
		next if uri.length <= (options[:length] ? options[:length].to_i : 42)

		begin timeout (options[:timeout] || 5).to_f do
			message.gsub!(/#{Regexp.escape(uri)}/, Shortie::Service.find_by_key(options[:service]).shorten(uri))
		end rescue Timeout::Error end
	}
end

on :message, priority: -100 do |chain=:input, from, to, message|
	return unless chain == :output

	if to.modes.extended.tinyurl_preview
		message.gsub!('http://tinyurl.com', 'http://preview.tinyurl.com')
	end
end
