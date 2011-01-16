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

require 'failirc/callback'

module IRC

class Module
  def self.get; @@last; end

  attr_accessor :owner, :config
  attr_reader   :name, :version, :events, :custom

  def self.define (name, version, owner=nil, &block)
    @@last = Module.new(name, version, &block)

    @@last.owner = owner if owner
  end

  def initialize (name, version, &block)
    @name    = name
    @version = version

    @aliases = {
      :input  => {},
      :output => {}
    }

    @events = {
      :input  => {},
      :output => {}
    }

    @custom = {}

    self.instance_eval(&block)
  end

  def input (&block)
    tmp, @into = @into, :input
    self.instance_eval(&block)
    @into = tmp
  end

  def output (&block)
    tmp, @into = @into, :output
    self.instance_eval(&block)
    @into = tmp
  end

  def aliases (&block)
    return @aliases unless @into

    on = InsensitiveStruct.new
    on.instance_eval(&block)

    on.to_hash.each {|name, value|
      @aliases[@into][name] = value
    }
  end

  def fallback (priority=0, &block)
    return unless @into

    (@events[@into][:fallback] ||= []) << Callback.new(block, priority)
  end

  def before (priority=0, &block)
    return unless @into

    (@events[@into][:before] ||= []) << Callback.new(block, priority)
  end

  def after (priority=0, &block)
    return unless @into

    (@events[@into][:after] ||= []) << Callback.new(block, priority)
  end

  def on (what, priority=0, &block)
    if @into
      (@events[@into][what] ||= []) << Callback.new(block, priority)
    else
      observe(what, priority, &block)
    end
  end

  def observe (what, priority=0, &block)
    (@custom[what] ||= []) << Callback.new(block, priority)
  end

  def fire (what, *args, &block)
    if @owner
      @owner.fire(what, *args, &block)
    else
      catch(:halt) {
        Event.new(self, :custom, @custom[what] || []).call(*args, &block)
      }
    end
  end

  def method_missing (id, *args, &block)
    (@aliases[@into][id.to_sym.downcase] rescue nil) || (@owner.alias(@into, id) rescue nil) || id
  end
end

end
