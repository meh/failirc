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

version    '0.0.1'
identifier 'tls'

Base.command_executable_when_unregistered :STARTTLS

RPL_STARTTLS = {
	code: 670,
	text: ':STARTTLS successful, go ahead with TLS handshake'
}

input {
	aliases {
		starttls /^STARTTLS( |$)/i
	}

	on :starttls do |thing, string|
		next if thing.ssl?

		thing.send_message RPL_STARTTLS
		thing.ssl!
	end
}
