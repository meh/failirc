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

module IRC

module Utils

def debug (argument)
    if self.verbose
        if argument.kind_of?(Exception)
            puts "#{self.class}: #{argument.class}: #{argument.message}"
            puts argument.backtrace.collect {|stack|
                "#{self.class}: #{stack}"
            }.join("\n")
            puts "\n"
        else
            puts "#{self.class}: #{argument}\n\n"
        end
    end
end

end

end
