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

require 'failirc/server/errors'
require 'failirc/server/module'
require 'failirc/server/client'

Class.new(IRC::Server::Module) do
    def checkRegistration (type, thing, string)
        # if the client tries to do something without having registered, kill it with fire
        if type != :PASS && type != :NICK && type != :USER && !thing.registered?
            thing.send(:numeric, ERR_NOTREGISTERED)
        # if the client tries to reregister, kill it with fire
        elsif type == :PASS || type == :NICK || type == :USER && thing.registered?
            thing.send(:numeric, ERR_ALREADYREGISTRED)
        else
            return true
        end

        return false
    end

    def auth (thing, string)
        match = string.match(/PASS\s+(.+)$/)

        if !match
            thing.send(:numeric, ERR_NEEDMOREPARAMS, 'PASS')
        else
            thing.password = match[1]
        end
    end

    def nick (thing, string)
        if !thing.is_a?(Client)
            return
        end

        match = string.match(/NICK\s+(.+)$/)

        # no nickname was passed, so tell the user is a faggot
        if !match
            thing.send(:numeric, ERR_NONICKNAMEGIVEN)
            return
        end
        
        # check if the nickname is valid
        if !match[1].match(/[\w\-^\/]{1,23}/
            thing.send(:numeric, ERR_ERRONEUSNICKNAME, match[1])
            return
        end

        if !thing.registered?
            # if the user hasn't registered yet and the choosen nick is already used,
            # kill it with fire.
            if thing.server.users[match[1]]
                thing.send(:numeric, ERR_NICKCOLLISION, match[1])
                thing.server.kill(thing)
            else
                thing.nick = match[1]
            end
        else
            # if the user has already registered and the choosen nick is already used,
            # just tell him that he's a faggot.
            if thing.server.users[match[1]]
                thing.send(:numeric, ERR_NICKNAMEINUSE, match[1])
            else
                mask       = thing.mask
                thing.nick = match[1]

                # create an empty hash to put single users to notice the nick change
                users = {}

                # notice all the channel where the user is in that he changed nick
                thing.channels.each {|channel|
                    channel.users.each {|user|
                        users[user.nick] = user
                    }
                }

                users.each {|user|
                    user.send :raw "#{mask} NICK :#{thing.nick}"
                }
            end
        end

        # if the client isn't registered but has all the needed attributes, register it
        if !thing.registered?
            if thing.user && thing.nick && (thing.listen.attributes['password'] && thing.listen.attributes['password'] == thing.password)
                thing.registered = true

                # clean the temporary hash value and use the nick as key
                thing.server.users.delete(thing.socket)
                thing.server.users[thing.nick] = thing
            end
        end
    end

    def user (thing, string)
        
    end

    @defaultEvents = {
        :PASS => /^PASS( |$)/,
        :NICK => /^(:[^ ] )?NICK( |$)/,
        :USER => /^(:[^ ] )?USER( |$)/,
    }

    @events = {
        :default => checkRegistration,

        :PASS => auth,
        :NICK => nick,
        :USER => user,
    }
end
