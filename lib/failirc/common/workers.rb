#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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
#++

require 'actionpool'

module IRC

class Workers
  extend Forwardable

  attr_reader    :parent
  def_delegators :@pool, :max, :max=, :min, :min=

  def initialize (parent, range = 2 .. 4)
    @parent = parent

    @pool = ActionPool::Pool.new(:min_threads => range.begin, :max_threads => range.end)
  end

  def do (*args, &block)
    @pool.process(*args, &block)
  end
end

end
