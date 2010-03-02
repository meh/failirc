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

require 'failirc/server/event'

module IRC

class Module
    attr_reader :server

    def initialize (server)
        @server = server

        if @aliases
            if @aliases[:input]
                @aliases[:input].each {|key, value|
                    @server.dispatcher.alias(:input, key, value)
                }
            end

            if @aliases[:output]
                @aliases[:output].each {|key, value|
                    @server.dispatcher.alias(:output, key, value)
                }
            end
        end

        if @events
            if @events[:pre]
                @server.dispatcher.register(:pre, nil, @events[:pre])
            end

            if @events[:post]
                @server.dispatcher.register(:post, nil, @events[:post])
            end

            if @events[:default]
                @server.dispatcher.register(:default, nil, @events[:default])
            end
            
            if @events[:custom]
                @events[:custom].each {|key, value|
                    @server.dispatcher.register(:custom, key, value)
                }
            end

            if @events[:input]
                @events[:input].each {|key, value|
                    @server.dispatcher.register(:input, key, value)
                }
            end

            if @events[:output]
                @events[:output].each {|key, value|
                    @server.dispatcher.register(:output, key, value)
                }
            end
        end
    end

    def finalize
        if @aliases
            @aliases.each_key {|key|
                @server.dispatcher.alias(key, nil)
            }
        end

        if @events
            @events.each_key {|key|
                @server.dispatcher.register(key, nil)
            }
        end
    end
end

end
