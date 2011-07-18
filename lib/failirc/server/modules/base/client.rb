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

module Client
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

  def self.extended (obj)
    obj.instance_eval {
      @channels = Channels.new(server)
      @modes    = Modes.new

      @mask      = Mask.new
      @mask.host = self.host

      if ssl?
        @modes + :ssl
      end

      @connected_on = Time.now
      @registered   = false

      @encoding = 'UTF-8'
    }

    class << obj
      extend Forwardable

      attr_reader    :channels, :mask, :connected_on, :modes
      attr_accessor  :password, :real_name, :message, :away, :encoding, :last_action
      def_delegators :@mask, :nick, :nick=, :user, :user=, :host, :host=
      def_delegators :@modes, :can

      def is_on_channel? (name)
        if name.is_a?(Channel)
          !!name.user(self)
        else
          !!@channels[(name.to_s.is_valid_channel?) ? name : "##{name}"]
        end
      end

      def away?
        !!away
      end

      def identifier
        nick
      end

      def incoming?
        false
      end

      def client?
        true
      end

      def to_s
        mask.to_s
      end
    end
  end
end

end; end; end
