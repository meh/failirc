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

require 'failirc/server/module'

module IRC

class Server

module Modules

class Cloaking < Module
    def initialize (server)
        @aliases = {
            :output => {
                :NAMES => /:.*? 353 /,
            },

            :input => {
                :DISGUISEAS => /^DISGUISEAS( |$)/i,
            },
        }

        @events = {
            :custom => {
                :message => Event::Callback.new(self.method(:received_message), -100),
                :notice  => Event::Callback.new(self.method(:received_notice), -100),
                :ctcp    => Event::Callback.new(self.method(:received_ctcp), -100),

                :topic_change => Event::Callback.new(self.method(:topic_change), -100),
            },

            :output => {
                :NAMES => Event::Callback.new(self.method(:hide), -100),
            },

            :input => {
                :DISGUISEAS => self.method(:disguiseas),
            },
        }

        @disguises = {}

        super(server)
    end

    def disguiseas (thing, string)
        match = string.match(/DISGUISEAS\s+(.+?)$/i)

        if !thing.modes[:operator]
            thing.send :numeric, ERR_NOPRIVILEGES
            return
        end

        if !match
            @disguises.delete(thing)
        else
            mask = match[1].strip

            if mask.match(/^.+!.+@.+$/)
                @disguises[thing] = Mask::parse(mask)
            else
                @disguises[thing] = mask
            end
        end
    end

    def disguise (fromRef)
        from = fromRef.value

        if from.modes[:operator]
            if @disguises[from].is_a?(Mask)
                fromRef.value = Client.new(server, @disguises[from])
            elsif tmp = server.clients[@disguises[from]]
                fromRef.value = tmp
            end
        end
    end

    def received_message (chain, fromRef, toRef, message, level=nil)
        if chain != :input
            return
        end

        disguise(fromRef)
    end

    def received_notice (chain, fromRef, toRef, message, level=nil)
        if chain != :input || fromRef.value.is_a?(Server)
            return
        end

        disguise(fromRef)
    end

    def received_ctcp (chain, kind, fromRef, toRef, type, message, level)
        if chain != :input || fromRef.value.is_a?(Server)
            return
        end

        disguise(fromRef)
    end

    def topic_change (channel, topic, fromRef)
        disguise(fromRef)
    end

    def hide (thing, string)
        match = string.match(/:.*? (\d+)/)

        if !match
            return
        end

        self.method("_#{match[1]}".to_sym).call(thing, string) rescue nil
    end

    def _353 (thing, string)
        if thing.modes[:operator]
            return
        end

        match = string.match(/353 .*?:(.*)$/)

        names = match[1].split(/\s+/)
        list  = ''

        names.each {|original|
            if Base::User::levels.has_value(original[0, 1])
                name = original[1, original.length]
            else
                name = original
            end

            if !server.clients[name]
                next
            end

            client = server.clients[name]

            if !(client.modes[:operator] && client.modes[:extended][:hide])
                list << " #{original}"
            end
        }

        string.sub!(/ :(.*)$/, " :#{list[1, list.length]}")
    end
end

end

end

end
