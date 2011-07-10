#--
# copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
#
# this file is part of failirc.
#
# failirc is free software: you can redistribute it and/or modify
# it under the terms of the gnu affero general public license as published
# by the free software foundation, either version 3 of the license, or
# (at your option) any later version.
#
# failirc is distributed in the hope that it will be useful,
# but without any warranty; without even the implied warranty of
# merchantability or fitness for a particular purpose.  see the
# gnu affero general public license for more details.
#
# you should have received a copy of the gnu affero general public license
# along with failirc. if not, see <http://www.gnu.org/licenses/>.
#++

require 'failirc/common/events'

module IRC

class Module
  include Events::DSL

  def self.define (*args, &block)
    self.new(*args, &block)
  end

  def initialize (data={}, &block)
    Events::DSL.initialize(self)

    @data = data
  end

  def method_missing (id, *args, &block)
    @data[id] ? @data[id] : super
  end
end

end
