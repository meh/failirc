# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.doesntexist.org | meh.ffff@gmail.com]
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

module IRC

class Mask
    attr_accessor :nick, :user, :host

    def initialize (nick=nil, user=nil, host=nil)
        @nick = nick
        @user = user
        @host = host
    end

    def match (mask)
        if !mask || mask.is_a?(String)
            mask = Mask.parse(mask || '*!*@*')
        end

        matches = {}

        if !nick || !mask.nick || Mask.toRegexp(nick).match(mask.nick)
            matches[:nick] = true
        end

        if !user || !mask.user || Mask.toRegexp(user).match(mask.user)
            matches[:user] = true
        end

        if !host || !mask.host || Mask.toRegexp(host).match(mask.host)
            matches[:host] = true
        end

        return matches[:nick] && matches[:user] && matches[:host]
    end

    def == (mask)
        if @nick == mask.nick && @user == mask.user && @host == mask.host
            return true
        end
    end

    def != (mask)
        !(self == mask)
    end

    def to_s
        return "#{nick || '*'}!#{user || '*'}@#{host || '*'}"
    end

    def self.toRegexp (string)
        return Regexp.new(Regexp.escape(string).gsub(/\\\*/, '.*?').gsub(/\\\?/, '.'))
    end

    def self.parse (string)
        match = string.match(/^((.+?)!)?(.+?)(@(.+?))?$/)

        if !match[2] || match[2] == '*'
            nick = nil
        else
            nick = match[2]
        end

        if match[3] == '*'
            user = nil
        else
            user = match[3]
        end

        if !match[5] || match[5] == '*'
            host = nil
        else
            host = match[5]
        end

        return Mask.new(nick, user, host)
    end
end

end
