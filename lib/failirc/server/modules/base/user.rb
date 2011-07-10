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

class User

  Modes = IRC::Modes.define {
    service :!,
      must:     :give_channel_service,
      inherits: :owner

    owner :x,
      must:     :give_channel_owner,
      inherits: :admin,
      powers:   [:give_channel_admin]

    admin :y,
      must:     :give_channel_admin,
      inherits: :operator

    operator :o,
      must:     :give_channel_operator,
      inherits: :halfop,
      powers:   [:moderate_channel, :change_user_modes]

    halfop :h,
      must:     :give_channel_halfop,
      inherits: :voice,
      powers:   [:kick]

    voice :v,
      must:   :give_channel_voice,
      powers: [:talk]
  }

  Levels = {
    :! => '!',
    :x => '~',
    :y => '&',
    :o => '@',
    :h => '%',
    :v => '+'
  }

  class ::String
    def is_level?
      Levels.has_value?(self) ? self : false
    end
  end

  attr_reader :client, :channel, :modes

  def initialize (client, channel)
    @client  = client
    @channel = channel
    @modes   = Modes.new

    @data = InsensitiveStruct.ne

    if block_given?
      yield self
    end
  end

  def method_missing (id, *args, &block)
    if @client.respond_to? id
      @client.__send__ id, *args, &block
    else
      super
    end
  end

  def is_level_enough? (level)
    return true if !level || (level.is_a?(String) && level.empty?)

    if level.is_a?(String)
      level = Levels.key level
    end

    highest = highest_level

    return false unless highest

    highest = Levels.keys.index(highest)
    level   = Levels.keys.index(level)

    if !level
      return true
    elsif !highest
      return false
    else
      return highest <= level
    end
  end

  def highest_level
    Levels.each_key {|level|
      return level if modes[level]
    }
  end

  # TODO: finish this shit
  def level= (level, value = true)
    level = Levels[level] ? level : Level.key(level)
  end

  def to_s
    return "#{modes[:level]}#{nick}"
  end

  def inspect
    return "#<User: #{client.inspect} #{channel.inspect} #{modes.inspect}>"
  end
end

end; end; end
