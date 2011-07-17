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

require 'failirc/server/modules/base/channel'

module IRC; class Server; module Base
 
class Channels < ThreadSafeHash
  attr_reader :server

  def initialize (server, *args)
    @server = server

    super(*args)
  end

  def delete (channel)
    if channel.is_a?(Channel)
      super(channel.name)
    else
      super(channel)
    end
  end

  def add (channel)
    self[channel.name] = channel
  end

  # get single users in the channels
  def clients
    result = Clients.new(server)

    each_value {|channel|
      channel.users.each {|nick, user|
        result[nick] = user.client
      }
    }

    return result
  end

  def to_s (thing=nil)
    map {|(_, channel)|
      if thing.is_a?(Client) || thing.is_a?(User)
        "#{channel.user(thing).modes[:level]}#{channel.name}"
      else
        "#{channel.name}"
      end
    }.join(' ')
  end
end

end; end; end
