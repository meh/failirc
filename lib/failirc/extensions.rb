#--
# failirc, a fail IRC library.
#
# Copyleft meh. [http://meh.doesntexist.org | meh@paranoici.org]
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

require 'thread'

class Reference
  def initialize (name, vars)
    @getter = eval "lambda { #{name} }", vars
    @setter = eval "lambda { |v| #{name} = v }", vars
  end
  
  def value
    @getter.call
  end
  
  def value= (val)
    @setter.call(val)
  end
end

def ref (&block)
  Reference.new(block.call, block.binding)
end

class String
  def interpolate (on=nil)
    begin
      if !on || on.is_a?(Binding)
        (on || binding).eval("%{#{self}}")
      else
        on.instance_eval("%{#{self}}")
      end
    rescue Exception => e
      IRC.debug e
      self
    end
  end
end

class ThreadSafeCounter
  def initialize
    @semaphore = Mutex.new
    @number    = 0
    
    super
  end

  def increment
    @semaphore.synchronize {
      @number += 1
    }
  end

  def decrement
    @semaphore.synchronize {
      @number -= 1
    }
  end

  def to_i
    @semaphore.synchronize {
      @number
    }
  end
end

class InsensitiveStruct
  def initialize (data={})
    @data = {}

    data.each {|name, value|
      self.send name, value
    }
  end

  def method_missing (id, *args, &block)
    name = id.to_s.downcase

    if name.end_with?('=')
      name[-1] = ''
    end

    if args.length > 0
      @data[name.to_sym] = args.shift
    else
      @data[name.to_sym]
    end
  end

  def to_hash
    @data.clone
  end
end

class Hash
  # Return a new hash with all keys converted to strings.
  def stringify_keys
    dup.stringify_keys!
  end

  # Destructively convert all keys to strings.
  def stringify_keys!
    keys.each do |key|
      self[key.to_s] = delete(key)
    end
    self
  end

  # Return a new hash with all keys converted to symbols, as long as
  # they respond to +to_sym+.
  def symbolize_keys
    dup.symbolize_keys!
  end

  # Destructively convert all keys to symbols, as long as they respond
  # to +to_sym+.
  def symbolize_keys!
    keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end
    self
  end

  alias_method :to_options,  :symbolize_keys
  alias_method :to_options!, :symbolize_keys!

  # Validate all keys in a hash match *valid keys, raising ArgumentError on a mismatch.
  # Note that keys are NOT treated indifferently, meaning if you use strings for keys but assert symbols
  # as keys, this will fail.
  #
  # ==== Examples
  #   { :name => "Rob", :years => "28" }.assert_valid_keys(:name, :age) # => raises "ArgumentError: Unknown key(s): years"
  #   { :name => "Rob", :age => "28" }.assert_valid_keys("name", "age") # => raises "ArgumentError: Unknown key(s): name, age"
  #   { :name => "Rob", :age => "28" }.assert_valid_keys(:name, :age) # => passes, raises nothing
  def assert_valid_keys(*valid_keys)
    unknown_keys = keys - [valid_keys].flatten
    raise(ArgumentError, "Unknown key(s): #{unknown_keys.join(", ")}") unless unknown_keys.empty?
  end
end

class HashWithIndifferentAccess < Hash
  def extractable_options?
    true
  end

  def initialize(constructor = {})
    if constructor.is_a?(Hash)
      super()
      update(constructor)
    else
      super(constructor)
    end
  end

  def default(key = nil)
    if key.is_a?(Symbol) && include?(key = key.to_s)
      self[key]
    else
      super
    end
  end

  def self.new_from_hash_copying_default(hash)
    HashWithIndifferentAccess.new(hash).tap do |new_hash|
      new_hash.default = hash.default
    end
  end

  alias_method :regular_writer, :[]= unless method_defined?(:regular_writer)
  alias_method :regular_update, :update unless method_defined?(:regular_update)

  # Assigns a new value to the hash:
  #
  #   hash = HashWithIndifferentAccess.new
  #   hash[:key] = "value"
  #
  def []=(key, value)
    regular_writer(convert_key(key), convert_value(value))
  end

  alias_method :store, :[]=

  # Updates the instantized hash with values from the second:
  #
  #   hash_1 = HashWithIndifferentAccess.new
  #   hash_1[:key] = "value"
  #
  #   hash_2 = HashWithIndifferentAccess.new
  #   hash_2[:key] = "New Value!"
  #
  #   hash_1.update(hash_2) # => {"key"=>"New Value!"}
  #
  def update(other_hash)
    other_hash.each_pair { |key, value| regular_writer(convert_key(key), convert_value(value)) }
    self
  end

  alias_method :merge!, :update

  # Checks the hash for a key matching the argument passed in:
  #
  #   hash = HashWithIndifferentAccess.new
  #   hash["key"] = "value"
  #   hash.key? :key  # => true
  #   hash.key? "key" # => true
  #
  def key?(key)
    super(convert_key(key))
  end

  alias_method :include?, :key?
  alias_method :has_key?, :key?
  alias_method :member?, :key?

  # Fetches the value for the specified key, same as doing hash[key]
  def fetch(key, *extras)
    super(convert_key(key), *extras)
  end

  # Returns an array of the values at the specified indices:
  #
  #   hash = HashWithIndifferentAccess.new
  #   hash[:a] = "x"
  #   hash[:b] = "y"
  #   hash.values_at("a", "b") # => ["x", "y"]
  #
  def values_at(*indices)
    indices.collect {|key| self[convert_key(key)]}
  end

  # Returns an exact copy of the hash.
  def dup
    HashWithIndifferentAccess.new(self)
  end

  # Merges the instantized and the specified hashes together, giving precedence to the values from the second hash
  # Does not overwrite the existing hash.
  def merge(hash)
    self.dup.update(hash)
  end

  # Performs the opposite of merge, with the keys and values from the first hash taking precedence over the second.
  # This overloaded definition prevents returning a regular hash, if reverse_merge is called on a HashWithDifferentAccess.
  def reverse_merge(other_hash)
    super self.class.new_from_hash_copying_default(other_hash)
  end

  def reverse_merge!(other_hash)
    replace(reverse_merge( other_hash ))
  end

  # Removes a specified key from the hash.
  def delete(key)
    super(convert_key(key))
  end

  def stringify_keys!; self end
  def stringify_keys; dup end
  undef :symbolize_keys!
  def symbolize_keys; to_hash.symbolize_keys end
  def to_options!; self end

  # Convert to a Hash with String keys.
  def to_hash
    Hash.new(default).merge!(self)
  end

  protected
    def convert_key(key)
      key.kind_of?(Symbol) ? key.to_s : key
    end

    def convert_value(value)
      case value
      when Hash
        self.class.new_from_hash_copying_default(value)
      when Array
        value.collect { |e| e.is_a?(Hash) ? self.class.new_from_hash_copying_default(e) : e }
      else
        value
      end
    end
end

class CaseInsensitiveHash < Hash
  def initialize (*args)
    super(*args)
  end

  alias ___set___ []=
  alias ___get___ []
  alias ___delete___ delete

  def []= (key, value)
    if key.is_a?(String)
      key = key.downcase
    end

    ___set___(key, value)
  end

  def [] (key)
    if key.is_a?(String)
      key = key.downcase
    end
    
    return ___get___(key)
  end

  def delete (key)
    if key.is_a?(String)
      key = key.downcase
    end

    ___delete___(key)
  end
end

class ThreadSafeHash < CaseInsensitiveHash
  def initialize (*args)
    @semaphore = Mutex.new

    super(*args)
  end

  alias __set__ []=
  alias __get__ []
  alias __delete__ delete

  def []= (key, value)
    begin
      @semaphore.synchronize {
        return __set__(key, value)
      }
    rescue ThreadError
      return __set__(key, value)
    end
  end

  def [] (key)
    begin
      @semaphore.synchronize {
        return __get__(key)
      }
    rescue ThreadError
      return __get__(key)
    end
  end

  def delete (key)
    begin
      @semaphore.synchronize {
        return __delete__(key)
      }
    rescue ThreadError
      return __delete__(key)
    end
  end
end
