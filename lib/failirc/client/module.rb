# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.doesntexist.org | meh@paranoici.org]
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

require 'failirc/utils'

module IRC

class Client

class Module
    attr_reader :client

    def initialize (client)
        @client = client

        if @aliases
            if @aliases[:input]
                @aliases[:input].each {|key, value|
                    @client.dispatcher.alias(:input, key, value)
                }
            end

            if @aliases[:output]
                @aliases[:output].each {|key, value|
                    @client.dispatcher.alias(:output, key, value)
                }
            end
        end

        if @events
            if @events[:pre]
                @client.dispatcher.register(:pre, nil, @events[:pre])
            end

            if @events[:post]
                @client.dispatcher.register(:post, nil, @events[:post])
            end

            if @events[:default]
                @client.dispatcher.register(:default, nil, @events[:default])
            end
            
            if @events[:custom]
                @events[:custom].each {|key, value|
                    @client.dispatcher.register(:custom, key, value)
                }
            end

            if @events[:input]
                @events[:input].each {|key, value|
                    @client.dispatcher.register(:input, key, value)
                }
            end

            if @events[:output]
                @events[:output].each {|key, value|
                    @client.dispatcher.register(:output, key, value)
                }
            end
        end

        begin
            rehash
        rescue NameError
        rescue Exception => e
            self.debug e
        end
    end

    def finalize
        if @aliases
            @aliases.each_key {|key|
                @client.dispatcher.alias(key, nil)
            }
        end

        if @events
            @events.each_key {|key|
                @client.dispatcher.register(key, nil)
            }
        end
    end
end

end

end
