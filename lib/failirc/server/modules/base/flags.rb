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

module Flags
	Groups = {
		can_change_channel_modes: [
			:can_change_channel_extended_modes, :can_change_topic_mode,
			:can_change_no_external_messages_mode, :can_change_secret_mode,
			:can_change_ssl_mode, :can_change_moderated_mode,
			:can_change_invite_only_mode, :can_change_auditorium_mode,
			:can_change_anonymous_mode, :can_change_limit_mode,
			:can_change_redirect_mode, :can_change_noknock_mode,
			:can_add_invitation, :can_channel_ban, :can_add_ban_exception,
			:can_change_channel_password, :can_change_nocolors_mode,
			:can_change_noctcp_mode, :can_change_no_nick_change_mode,
			:can_change_nokicks_mode, :can_change_strip_colors_mode,
			:can_change_noinvites_mode, :can_change_private_mode,
		],

		can_change_user_modes: [
			:can_give_channel_operator, :can_give_channel_half_operator,
			:can_give_voice, :can_change_user_extended_modes,
		],

		can_change_client_modes: [
			:can_change_client_extended_modes,
		],

		channel_moderation: [
			:can_invite, :can_kick, :can_change_topic, :can_change_channel_modes
		]
	}

	def set_flag (type, value, inherited=false, force=false)
		if !inherited
			if value == false
				self.modes.delete(type)
			else
				self.modes[type] = value
			end
		end

		return unless modes = (self.class::Modes[type] || Groups[type])
		
		if !modes.is_a?(Array)
			modes = [modes]
		end

		modes.each {|mode|
			if (self.class::Modes[mode] || Groups[mode]) && !self.has_flag?(mode)
				set_flag mode, value, !force
			else
				if value == false
					if !self.class::Modes.has_key?(mode)
						self.modes.delete(mode)
					end
				else
					self.modes[mode] = value
				end
			end
		}
	end

	def has_flag? (type)
		self.modes[type] || self.modes[:extended][type] || false
	end
end

end; end; end
