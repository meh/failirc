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

require 'failirc/server/modules/base/channel/topic'
require 'failirc/server/modules/base/channel/modifier'

module IRC; class Server; module Base

class Channel
  Modes = IRC::Modes.define {
    anonymous :a
  }

  Modes = {
    :a => :anonymous,
    :c => :no_colors,
    :C => :no_ctcps,
    :i => :invite_only,
    :l => :limit,
    :L => :redirect,
    :k => :password,
    :K => :no_knock,
    :m => :moderated,
    :n => :no_external_messages,
    :N => :no_nick_change,
    :p => :private,
    :Q => :no_kicks,
    :s => :secret,
    :S => :strip_colors,
    :t => :topic_lock,
    :u => :auditorium,
    :V => :no_invites,
    :z => :ssl_only,
  }

  class ::String
    def is_valid_channel?
      !!self.to_s.match(/^[&#+!][^ ,:\a]{0,50}$/)
    end

    def channel_type
      self[0] if self.is_valid_channel?
    end
  end

  attr_reader :server, :name, :type, :created_on, :modes, :topic, :data
  attr_writer :level

  def initialize (server, name)
    raise ArgumentError.new('It is not a valid channel name') unless name.is_valid_channel?

    @server = server
    @name   = name
    @type   = name[0, 1]

    @created_on = Time.now
    @users      = Users.new(self)
    @modes      = Modes.new
    @topic      = Topic.new(self)

    @data       = InsensitiveStruct.new
  end

  def method_missing (id, *args, &block)
    if @users.respond_to? id
      @users.__send__ id, *args, &block
    else
      super
    end
  end

  def type
    @name[0, 1]
  end

  def topic= (data)
    if data.is_a?(Topic)
      @topic.set_by = data.set_by
      @topic.text   = data.text
    elsif data.is_a?(Array)
      @topic.set_by = data[0]
      @topic.text  = data[1]
    end
  end

  def users
    if @level
      users = Users.new(self)
      
      @users.select {|_, user|
        user.is_level_enough?(@level)
      }.each {|_, user|
        user    = user.clone
        channel = self

        user.instance_eval '@channel = channel'

        users.add(user)
      }

      users
    else
      @users
    end
  end

  def user (client)
    @users[client]
  end

  def send (*args)
    users.send(*args)
  end

  def banned? (client)
    modes[:bans].each {|ban|
      return true if ban.match(client.mask)
    }

    return false
  end

  def exception? (client)
    modes[:exceptions].each {|exception|
      return true if exception.match(client.mask)
    }

    return false
  end

  def invited? (client, shallow=false)
    return true if shallow && !channel.has_flag?(:invite_only)

    return true if channel.data.invited[client.mask]

    modes[:invites].each {|invite|
      return true if invite.match(client.mask)
    }

    return false
  end

  def to_s
    @name
  end

  def level?
    @level
  end

  def level (level)
    return self unless User::Levels.has_value?(level)

    result       = self.clone
    result.level = level

    result
  end
end

end; end; end
