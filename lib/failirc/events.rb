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

require 'failirc/utils'

require 'failirc/events/event'

module IRC

class Events
  attr_reader :server, :aliases, :events

  def initialize (server)
    @server   = server
    @handling = ThreadSafeHash.new

    @aliases = {
      :input  => {},
      :output => {}
    }

    @events = {
      :input  => {},
      :output => {}
    }

    @custom = {}

    @hooks = []
  end

  def hook (mod)
    @hooks << mod
  end

  def alias (chain, name, value=nil)
    if value
      @aliases[chain][name.to_s.downcase] = value
    else
      @aliases[chain][name.to_s.downcase] || @hooks.find {|hook|
        hook.aliases[chain][name]
      }
    end
  end

  def event (chain, what)
    if what.is_a?(Symbol)
      Event.new(self, chain, ((@events[chain][what] || []) + @hooks.map {|hook| hook.events[chain][what]}).flatten.compact)
    else
      Event.new(self, chain, (@hooks.map {|hook| hook.events[chain]} + @events[chain].to_a).flatten.compact.select {|(name, callbacks)|
        name.class == Regexp
      }.select {|(regexp, callbacks)|
        what.to_s.match(regexp)
      }.map {|(regexp, callbacks)|
        callbacks
      }.flatten)
    end
  end

  def dispatch (chain, thing, string)
    return unless thing

    catch(:halt) {
      event(chain, :before).on(thing, string).call

      if (tmp = event(chain, string)).callbacks.length > 0
        tmp.on(thing, string).call
      else
        event(chain, :fallback).on(thing, string).call
      end

      event(chain, :after).on(thing, string).call
    }
  end

  def register (chain, what, priority=0, &block)
    (@events[chain][what] ||= []) << Callback.new(block, priority)
  end

  def observe (what, priority=0, &block)
    (@custom[what] ||= []) << Callback.new(block, priority)
  end

  def fire (what, *args, &block)
    catch(:halt) {
      Event.new(self, :custom, ((@custom[what] || []) + @hooks.map {|hook| hook.custom[what]}).flatten.compact).call(*args, &block)
    }
  end
end

end
