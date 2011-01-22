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

require 'failirc/callback'
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
      @aliases[chain][name.to_sym.downcase] = value
    else
      @aliases[chain][name.to_sym.downcase] || @hooks.find {|hook|
        hook.aliases[chain][name]
      }
    end
  end

  def event (chain, what)
    if what.is_a?(Symbol)
      Event.new(self, chain, ((@events[chain][what] || []) + @hooks.map {|hook| hook.events[chain][what]}).flatten.compact, [what])
    else
      callbacks = {}

      (@hooks + [self]).each {|hook|
        hook.events[chain].each {|key, value|
          (callbacks[key] ||= []).insert(-1, *value)
        }
      }

      regexps, callbacks = callbacks.to_a.select {|(name, callbacks)|
        !name.is_a?(Symbol)
      }.select {|(regexp, callbacks)|
        what.to_s.match(regexp) rescue nil
      }.transpose

      aliases = (regexps || []).flatten.compact.map {|regexp|
        @aliases[chain].select {|(name, value)|
          regexp == value
        }.map {|(name, value)|
          name
        } + @hooks.map {|hook|
          hook.aliases[chain].to_a.select {|(name, value)|
            regexp == value
          }.map {|(name, value)|
            name
          }
        }
      }.flatten.compact.uniq

      Event.new(self, chain, (callbacks || []).flatten.compact, aliases)
    end
  end

  def dispatch (chain=:input, thing, string)
    return unless thing

    current = event(chain, string).on(thing, string)

    catch(:halt) {
      event(chain, :before).call(current, thing, string)

      if current.callbacks.length > 0
        current.call
      else
        event(chain, :fallback).call(current, thing, string)
      end

      event(chain, :after).call(current, thing, string)
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
