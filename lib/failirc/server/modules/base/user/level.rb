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

module IRC; class Server; module Base; class User

class Level
  Modes = {
    :! => '!',
    :x => '~',
    :y => '&',
    :o => '@',
    :h => '%',
    :v => '+'
  }

  Priorities = [:!, :x,  :y, :o, :h, :v]

  attr_reader :user

  def initialize (user)
    @user = user
  end

  def enough? (level)
    return true if !level || (level.is_a?(String) && level.empty?)

    if level.is_a?(String)
      level = Modes.key level
    end

    return false unless highest

    highest = Modes.keys.index(highest)
    level   = Modes.keys.index(level)

    if !level
      true
    elsif !highest
      false
    else
      highest <= level
    end
  end

  def highest
    Priorities.each {|level|
      return level if user.modes[level].enabled?
    }
  end

  def + (key)
    user.modes[key].enable!
  end

  def - (key)
    user.modes[key].disable!
  end

  [:service?, :owner?, :admin?, :operator?, :halfop?, :voice?].each {|name|
    define_method name do
      user.modes.send name
    end
  }

  def to_s
    Modes[highest].to_s
  end
end

end; end; end; end
