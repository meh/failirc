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

require 'ipaddr'

version    '0.0.1'
identifier 'control'

def matches? (what, client)
	IPAddr.new(what).include?(client.ip) rescue Mask.parse(what).match(client.mask) rescue false
end

ban = -> client {
	next unless [options['ban']].flatten.compact.any? {|w| matches?(w, client) }

	server.fire :error, client, 'you are banned', :close
	client.disconnect 'you are banned'

	skip
}

limit_connections = -> client {
	next if options[:antiflood]['max connections per ip'].to_i <= 0

	next unless server.dispatcher.clients.count {|c|
		c.ip == client.ip && [options[:antiflood]['allow multiple connections from']].flatten.compact.none? {|w|
			matches?(w, c)
		}
	} > options[:antiflood]['max connections per ip'].to_i

	server.fire :error, client, 'too many connections from same client', :close
	client.disconnect 'too many connections from same client'

	skip
}

on :connect, &ban
on :connected, &ban

on :connect, &limit_connections
on :connected, &limit_connections

input {
	before priority: -98 do |event, thing, string|
		next if [options[:antiflood]['no speed limit for']].flatten.compact.any? { |w| matches?(w, thing) }

		sleep 0.5 if (Time.now - thing.last_action.on) < 0.2 rescue nil
	end

	observe :joined, priority: -98 do |thing, channel|
		sleep 0.5
	end
}
