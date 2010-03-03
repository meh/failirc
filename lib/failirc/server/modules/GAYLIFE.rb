# failirc, a fail IRC server.
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

require 'failirc/server/module'

module IRC

module Modules

class GAYLIFE < Module
    def initialize (server)
        @events = {
            :input => {
                :PRIVMSG => Event::Callback.new(self.method(:gay), -500),
            }
        }

        super(server)
    end

    def rehash
        @rainbow = @server.config.elements['config/modules/module[@name="GAYLIFE"]/rainbow']

        if @rainbow
            @rainbow = @rainbow.text
        else
            @rainbow = 'rrRRyyYYGGggccCCBBppPP'
        end
    end

    def gay (thing, string)
        match = string.match(/\s+(.*?)\s+:(.*)$/)

        if !match
            return
        end

        name    = match[1]
        message = match[2]

        if Channel.check(name) && thing.server.channels[name].modes[:gay] || thing.modes[:gay]
            string.sub!(/#{Regexp.escape(message)}/, gayify(message))
        end

        return string
    end

    def gayify (string)
        result   = ''
        position = 0

        string.each_char {|char|
            if position >= @rainbow.length
                position = 0
            end

            result << self.code(@rainbow[position, 1]) << char
            position += 1
        }

        return result
    end

    def self.code (char)
        return "\003#{Channel.colors[char.to_sym]}"
    end

    def self.colors
        return {
            :w => '15',
            :W => '0',
            :n => '1',
            :N => '14',
            :b => '2',
            :B => '12',
            :g => '3',
            :G => '9',
            :r => '5',
            :R => '4',
            :p => '6',
            :P => '13',
            :y => '7',
            :Y => '8',

            nil => ''
        }
    end
end

end

end
