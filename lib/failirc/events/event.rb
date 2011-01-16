#--
# failirc, a fail IRC library.
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
#++

require 'failirc/events/callback'

module IRC; class Events

class Event
  attr_reader :owner, :chain, :name, :callbacks, :thing, :string

  def initialize (owner, chain, callbacks)
    @owner     = owner
    @chain     = chain
    @callbacks = callbacks
  end

  def on (thing, string)
    @thing  = thing
    @string = string
    self
  end

  def call (*args, &block)
    @callbacks.sort {|a, b|
      a.priority <=> b.priority
    }.each {|callback|
      if @thing && @string
        callback.call(@thing, @string, *args, &block)
      else
        callback.call(*args, &block)
      end
    }
  end
end

end; end
