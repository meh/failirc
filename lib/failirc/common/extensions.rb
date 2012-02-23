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

require 'forwardable'
require 'yaml'
require 'call-me/memoize'
require 'refining'
require 'refr'
require 'socket'
require 'fcntl'
require 'timeout'
require 'thread/extra'

class Module
	def scopes_for (name)
		scopes  = []

		pieces = "Object::#{name}".split('::')
		until pieces.empty?
			scopes << eval(pieces.join('::')) rescue nil
			pieces.pop
		end

		scopes.compact!
		scopes.uniq!

		scopes
	end

	def scopes
		scopes_for(self.name)
	end
end

class Class
	def scopes
		Module.scopes_for(self.name)
	end
end

class Object
	def scopes
		self.class.scopes
	end; alias __scopes__ scopes

	def numeric?
		true if Float(self) rescue false
	end

	def merge_instance_variables (object)
		object.instance_variables.each {|var|
			instance_variable_set(var, object.instance_variable_get(var))
		}
	end
end

module Kernel
	def suppress_warnings
		exception = nil
		tmp, $VERBOSE = $VERBOSE, nil

		begin
			result = yield
		rescue Exception => e
			exception = e
		end

		$VERBOSE = tmp

		if exception
			raise exception
		else
			result
		end
	end
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

module StructLike
	def method_missing (id, *args)
		@data ||= {}

		id = id.to_s.sub(/[=?]$/, '').to_sym

		if args.length == 0
			return @data[id]
		else
			if respond_to? "#{id}="
				send "#{id}=", *args
			else
				value = (args.length > 1) ? args : args.first

				if value.nil?
					@data.delete(id)
				else
					@data[id] = value
				end
			end
		end
	end

	def to_hash
		@data.clone
	end
end

class InsensitiveStruct
	include StructLike

	def initialize (data={})
		@data = {}

		data.each {|name, value|
			__send__ name, value
		}
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
	def self.def_insensitive (*methods)
		methods.each {|method|
			define_method method do |key, *args, &block|
				if key.is_a?(String) || key.is_a?(Symbol)
					key = key.to_s.downcase
				end

				super(key, *args, &block)
			end
		}
	end

	def_insensitive :[], :[]=, :delete
end

class ThreadSafeHash < CaseInsensitiveHash
	def self.def_threaded (*methods)
		methods.each {|method|
			define_method method do |*args, &block|
				@semaphore.synchronize {
					super(*args, &block)
				}
			end
		}
	end

	def initialize (*args)
		@semaphore = RecursiveMutex.new

		super
	end

	def_threaded :[], :[]=, :delete, :each, :each_value, :each_key
end

class OpenSSL::SSL::SSLSocket
	def method_missing (*args, &block)
		to_io.__send__ *args, &block
	end
end
