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

class Client < Dispatcher::Client
  extend  Forwardable

  Modes = IRC::Modes.define {
    ssl :Z,
      must: :do_god

    netadmin :N,
      must:     :give_netadmin,
      inherits: :operator,
      powers:   [:give_netadmin, :give_ircop]

    operator :o,
      must: :give_ircop,
      powers: [
        :kill, :see_secrets,
        :give_channel_owner, :give_channel_admin, :channel_moderation,
        :change_user_modes, :change_client_modes
      ]
  }

  attr_reader    :channels, :mask, :connected_on, :data
  attr_accessor  :password, :real_name, :modes  
  def_delegators :@mask, :nick, :nick=, :user, :user=, :host, :host=
  def_delegators :@modes, :can

  def initialize (client, data={})
    client = client.client if client.is_a?(Base::Client)

    merge_instance_variables(client)

    @channels = Channels.new(server)
    @modes    = Modes.new

    if data[:mask]
      @mask = data[:mask]
    else
      @mask      = Mask.new
      @mask.host = client.host
    end

    if @client.ssl?
      @modes + :ssl
    end

    @connected_on = Time.now
    @registered   = false
    @data         = truct
  end

  def send (*args)
    if args.first.is_a?(String)
      super(args.first)
    else
      response, value = args
      begin
        super ":#{server.host} #{'%03d' % response[:code]} #{identifier} #{response[:text].interpolate(binding)}"
      rescue Exception => e
        IRC.debug response[:text]
        raise e
      end
    end
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
