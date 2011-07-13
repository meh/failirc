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

require 'failirc/common/modes/definitions'
require 'failirc/common/modes/mode'
require 'failirc/common/modes/can'

module IRC

class Modes
  def self.[] (name, value)
    Struct.new(:name, :value).new(name.to_sym, value)
  end

  def self.define (&block)
    Class.new(Modes) {
      @@definitions = Definitions.new(&block)
    }
  end

  def initialize (data=nil)
    @modes = HashWithIndifferentAccess.new

    if data.is_a?(Modes)
      @modes.merge!(data.to_hash)
    end
  end

  def method_missing (name, *args, &block)
    name = name.to_s

    begin
      if name.end_with?('?')
        self[name.sub('?', '')].enabled?
      else
        self[name]
      end
    rescue
      super(name.to_sym, *args, &block)
    end
  end

  def each (&block)
    @modes.values.uniq.each &block
  end

  memoize
  def [] (name)
    if !supports?(name)
      raise ArgumentError, "#{name} is not supported by #{inspect}"
    end

    return @modes[name] if @modes[name]

    definition = @@definitions.find(name)

    @modes[definition.name] = @modes[definition.code] = Mode.new(definition)
  end

  def + (data)
    data = Modes[data, true] if data.is_a?(Symbol)

    if !supports?(data.name)
      raise ArgumentError, "#{data.name} is not supported by #{inspect}"
    end

    mode = self[data.name]

    if @as.nil? or mode.must.all? {|name| @at.can.send name}
      mode.value = data.value
    end
  end

  def - (data)
    data = Modes[data, false] if data.is_a?(Symbol)

    if !supports?(data.name)
      raise ArgumentError.new "#{data.name} is not supported by #{inspect}"
    end

    mode = self[data.name]

    if @as.nil? or mode.must.all? {|name| @at.can.send name}
      mode.value = data.value
    end
  end

  def supports? (name)
    !!@@definitions.find(name)
  end

  def can
    Can.new(self)
  end

  def as (what)
    @as = what.is_a?(Modes) ? what : what.modes

    yield self

    @as = nil
  end

  def empty?
    each {|mode|
      return false if mode.enabled?
    }

    true
  end

  def to_hash
    @modes
  end

  def to_s
    modes  = []
    values = []

    each {|mode|
      next unless mode.enabled?

      modes  << mode.code
      values << mode.value unless mode.value === false or mode.value === true
    }

    "+#{modes.join}#{" #{values.join(' ')}" if values}"
  end

  def inspect
    @@definitions.to_s
  end
end

end
