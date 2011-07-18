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

module IRC; class Modes

class Mode
  extend Forwardable

  attr_reader    :definition
  attr_accessor  :value
  def_delegators :@definition, :name, :code

  def initialize (definition)
    @definition = definition
  end

  memoize
  def must
    [definition.options[:must]].flatten.compact.uniq
  end

  memoize
  def inherits
    [definition.options[:inherits]].flatten.compact.uniq
  end

  memoize
  def powers
    result = []

    ([definition] + inherits.map {|name| definition.parent.find(name)}).each {|definition|
      result.push(definition.options[:powers])
    }

    result.flatten.compact.uniq
  end

  def enabled?;  !!@value; end
  def disabled?; !@value; end

  def enable!;  @value = true; end
  def disable!; @value = false; end
end

end; end
