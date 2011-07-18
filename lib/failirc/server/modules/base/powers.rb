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

module Powers
  module Channel
    ChangeModes = [
      :change_topic_mode,
      :change_no_external_messages_mode, :change_secret_mode,
      :change_ssl_mode, :change_moderated_mode,
      :change_invite_only_mode, :change_auditorium_mode,
      :change_anonymous_mode, :change_limit_mode,
      :change_redirect_mode, :change_no_knocks_mode,
      :add_invitation, :channel_ban, :add_ban_exception,
      :change_channel_password, :change_no_colors_mode,
      :change_no_ctcps_mode, :change_no_nick_change_mode,
      :change_no_kicks_mode, :change_strip_colors_mode,
      :change_no_invites_mode, :change_private_mode,
    ]

    Moderation = [:invite, :kick, :change_topic, ChangeModes]
  end

  module User
    ChangeModes = [
      :give_channel_operator, :give_channel_halfop,
      :give_voice
    ]
  end

  module Client
    ChangeModes = []
  end
end

end; end; end
