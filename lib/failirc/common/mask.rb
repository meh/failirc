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

module IRC

class Mask
  def self.escape (str)
    Regexp.escape(str).gsub(/\\\*/, '[^!@]*?').gsub(/\\\?/, '[^!@]') rescue '[^!@]*?'
  end

  attr_accessor :nick, :user, :host

  def initialize (nick=nil, user=nil, host=nil)
    @nick = nick
    @user = user
    @host = host
  end

  def match (mask)
    mask = Mask.parse(mask) if !mask.is_a?(Mask)

    !!(mask.is_a?(Mask) ? mask : Mask.parse(mask || '*!*@*')).to_s.match(self.to_reg)
  end

  def == (mask)
    mask = Mask.parse(mask) if !mask.is_a?(Mask)

    @nick == mask.nick && @user == mask.user && @host == mask.host
  end

  def to_s
    "#{@nick || '*'}!#{@user || '*'}@#{@host || '*'}"
  end

  def to_reg
    Regexp.new("^(?:(#{Mask.escape(@nick)})(?:!|$))?(?:(#{Mask.escape(@user)})(?:@|$))(?:(#{Mask.escape(@host)}))?$", 'i')
  end

  def self.parse (mask)
    Mask.new *mask.scan(/^
      # nickname
      (?:
        ([^@!]*?) # nickname can contains all chars excluding '@' and '!'
        (?:!|$) # it must be followed by a '!' or end of string
      )?

      # username
      (?:
        ([^@!]*?) # username can contain all chars excluding '@' and '!'
        (?:@|$) # it must be followed by a '@' or end of string
      )?

      # hostname
      (.*?) # hostname can contain all chars
    $/x).flatten.map {|part|
      part.empty? ? nil : part
    } rescue []
  end
end

end
