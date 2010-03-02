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

require 'failirc/utils'
require 'failirc/server/responses'
require 'failirc/server/users'

module IRC

class Channel
    attr_reader :name, :createdOn, :users, :modes
    attr_accessor :topic

    def initialize (name)
        @name = name

        if !@name.match(/^[#&\$]/)
            @name = "##{@name}"
        end

        @createdOn = Time.now

        @users = Users.new(self)

        @modes = {}
    end

    def empty?
        return @users.empty?
    end
end

end
