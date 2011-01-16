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

require 'forwardable'

module IRC; class Server

class User
  extend Forwardable

  attr_reader :client, :channel, :modes

  def initialize (client, channel, modes=Modes.new)
    @client  = client
    @channel = channel
    @modes   = modes

    User.def_delegators :@client, :mask, :server, :data, :nick, :user, :host, :real_name, :send
  end

  def to_s
    return "#{modes[:level]}#{nick}"
  end

  def inspect
    return "#<User: #{client.inspect} #{channel.inspect} #{modes.inspect}>"
  end
end

end

end
