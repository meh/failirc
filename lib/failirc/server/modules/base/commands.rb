#--
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
#++

module IRC; class Server; module Base

module Commands
	NoAction     = [:PING, :PONG, :WHO, :MODE]
	Unregistered = [:PASS, :NICK, :USER]
	Unrepeatable = [:PASS, :USER]
end

def self.command_executable_when_unregistered (name)
	Commands::Unregistered << name.to_sym
end

def self.command_is_not_an_action (name)
	Commands::NoAction << name.to_sym
end

def self.command_is_unrepeatable (name)
	Commands::Unrepeatable << name.to_sym
end

end; end; end
