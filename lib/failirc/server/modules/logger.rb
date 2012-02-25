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

version '0.1.0'

on :start do
	@log = options[:file] ? File.open(options[:file]) : $stdout
end

on :stop do
	@log.close unless @log == $stdout
end

on :log do |string|
	@log.print "[#{Time.now}] #{string}\n"
end

on :connect do |client|
	server.fire :log, "#{client} connected"
end

on :disconnect do |client, message|
	server.fire :log, "#{client} disconnected because: #{message}"
end

logger = -> event, thing, string {
	server.fire :log, "#{(event.chain == :input) ? '*IN* ' : '*OUT*'} #{thing} #{string.inspect}"
}

input  { before priority: -100, &logger }
output { after  priority:  100, &logger }
