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

require 'failirc/extensions'
require 'failirc/server/channel'
require 'failirc/server/modes'
require 'failirc/server/module'

module IRC

module Modules

class WordFilter < Module
    def initialize (server)
        @events = {
            :custom => {
                :message => Event::Callback.new(self.method(:filter), -500),
            }
        }

        super(server)
    end

    def rehash
        # config for the rainbow filter
        if tmp = @server.config.elements['config/modules/module[@name="WordFilter"]/rainbow']
            @rainbow = tmp.text
        else
            @rainbow = 'rrRRyyYYGGggccCCBBppPP'
        end

        # config for the replaces filter
        @replaces = []

        if tmp = @server.config.elements['config/modules/module[@name="WordFilter"]/replaces']
            tmp.elements['replace'].each {|element|
                @replaces.push({ :from => element.attributes['word'], :to => element.attributes['with'] })
            }
        end
    end

    def filter (sender, receiver, message)
        channel = (receiver.is_a?(Channel)) ? receiver.modes : Modes.new
        client  = sender.modes

        if channel[:extended][:gay] || client[:extended][:gay]
            rainbow(message, 'rrRRyyYYGGggccCCBBppPP')
        end
    end

    def rainbow (string, pattern=@rainbow)
        string.gsub!(/\003(\d+(,\d+)?)?/, '')

        result   = ''
        position = 0

        string.each_char {|char|
            if position >= pattern.length
                position = 0
            end

            result << WordFilter.color(pattern[position, 1]) << char
            position += 1
        }

        string.assign!(result)
    end

    def self.color (char)
        return "\003#{@@colors[char.to_sym]}"
    end

    @@colors = {
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
        :c => '10',
        :C => '11',
        :p => '6',
        :P => '13',
        :y => '7',
        :Y => '8',

        nil => ''
    }
end

end

end
