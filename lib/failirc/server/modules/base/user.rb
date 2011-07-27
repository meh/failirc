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

require 'failirc/server/modules/base/user/extensions'
require 'failirc/server/modules/base/user/level'
require 'failirc/server/modules/base/user/can'

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
      powers:   [Powers::Channel::Moderation, Powers::User::ChangeModes]

    halfop :h,
      must:     :give_channel_halfop,
      inherits: :voice,
      powers:   [:kick]

    voice :v,
      must:   :give_channel_voice,
      powers: [:talk]
  }

  extend Forwardable

  attr_reader  :client, :channel, :modes, :level
  undef_method :send

  def initialize (client, channel)
    @client  = client
    @channel = channel
    @modes   = Modes.new

    @level = Level.new(self)

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

  memoize
  def can
    Can.new(self)
  end

  def to_s
    "#{level}#{nick}"
  end

  def inspect
    "#<User: #{client.inspect} #{channel.inspect} #{modes.inspect}>"
  end
end

end; end; end
