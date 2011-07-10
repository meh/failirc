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

class Client
  extend  Forwardable

  Modes = IRC::Modes.define {
    ssl :Z,
      :needs => :server

    netadmin :N,
      :needs    => :give_netadmin,
      :inherits => :operator,
      :powers   => [:give_netadmin]

    operator :o,
      :needs  => :give_operator,
      :powers => [
        :kill, :see_secrets,
        :give_channel_owner, :can_give_channel_admin, :channel_moderation,
        :can_change_user_modes, :can_change_client_modes
      ]
  }

  attr_reader    :channels, :mask, :connected_on
  attr_accessor  :password, :real_name, :modes  
  def_delegators :@client, :port, :ssl?
  def_delegators :@mask, :nick, :nick=, :user, :user=, :host, :host=
  def_delegators :@modes, :can

  def initialize (client, data={})
    @client = client.is_a?(Base::Client) ? client.client : client

    @channels = Channels.new(@server)
    @modes    = Modes.new

    @mask      = data[:mask] ? data[:mask] : Mask.new
    @mask.host = @client

    if @client.ssl?
      @modes + :ssl
    end

    @connected_on = Time.now
    @registered   = false
  end

  def is_on_channel? (name)
    if name.is_a?(Channel)
      !!name.user(self)
    else
      !!@channels[(name.to_s.is_valid_channel?) ? name : "##{name}"]
    end
  end

  def identifier
    nick
  end

  def to_s
    mask.to_s
  end
end

end; end; end
