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

class Definitions < Array
  class Definition < Struct.new(:name, :code, :options)
    attr_reader :parent

    def initialize (parent, *args)
      super(*args)

      @parent = parent
    end
  end

  def initialize (&block)
    self.instance_eval(&block)
  end

  def method_missing (name, code, options={})
    push Definition.new(self, name.to_sym, code.to_sym, options)
  end

  def find (name)
    name = name.to_sym

    super() {|definition|
      name == definition.name or name == definition.code
    }
  end
end

end; end
