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

require 'failirc/common/modules/module'

module IRC

class Modules
  attr_reader :owner, :list

  def initialize (owner, path)
    @owner = owner
    @path  = path

    @list = []
  end

  def load (name, options={})
    mod = Module.for(@owner).new(options)

    $:.each {|path|
      path = "#{path}/#{@path}/#{name}.rb"

      if File.readable?(path)
        begin
          mod.instance_eval(File.read(path), File.realpath(path), 1)

          return @list.push(mod).last
        rescue Exception => e
          IRC.debug e

          return false
        end
      end
    }

    raise LoadError, "#{name} not found"
  end
end

end