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

require 'thread'
require 'failirc/utils'
require 'failirc/server/responses'
require 'failirc/server/users'
require 'failirc/server/modes'

module IRC

class Channel
    class Topic
        attr_reader :server, :channel, :text, :setBy
        attr_accessor :setOn

        def initialize (channel)
            @server  = channel.server
            @channel = channel

            @semaphore = Mutex.new
        end

        def text= (value)
            @semaphore.synchronize {
                @text  = value
                @setOn = Time.now
            }
        end

        def setBy= (value)
            @setBy = value.mask.clone
        end

        def to_s
            text
        end

        def nil?
            text.nil?
        end
    end

    attr_reader :server, :name, :type, :createdOn, :users, :modes, :topic

    def initialize (server, name)
        @server = server
        @name   = name
        @type   = name[0, 1]

        @createdOn = Time.now
        @users     = Users.new(self)
        @modes     = Modes.new
        @topic     = Topic.new(self)

        @semaphore = Mutex.new
    end

    def type
        @name[0, 1]
    end

    def topic= (data)
        @semaphore.synchronize {
            if data.is_a?(Topic)
                @topic = data
            elsif data.is_a?(Array)
                @topic.setBy = data[0]
                @topic.text  = data[1]
            end
        }
    end

    def [] (user)
        users[user]
    end

    def add (user)
        users.add(user)
    end

    def delete (user)
        users.delete(user)
    end

    def user (client)
        return @users[client.nick]
    end

    def empty?
        return @users.empty?
    end

    def send (*args)
        users.send(*args)
    end

    def to_s
        @name
    end
end

end
