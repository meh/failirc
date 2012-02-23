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

module IRC; class Modules < Array

class Module
	def self.for (what)
		scopes = what.scopes

		Class.new(Module).tap {|klass|
			klass.define_singleton_method :const_missing do |name|
				scopes.each {|what|
					return what.const_get(name) if what.const_defined?(name)
				}

				super(name)
			end
		}.tap {|klass|
			klass.class_eval {
				define_method :inspect do
					"#<Module: for(#{what.class.name})>"
				end
			}
		}
	end

	include Events::DSL

	attr_reader :name, :options

	def initialize (name, options={})
		@name    = name
		@options = options

		Events::DSL.initialize(self)
	end

	def rehash (options=nil, &block)
		if block
			@rehash = block
		else
			@rehash.call(options) if @rehash
		end
	end

	[:version, :identifier].each {|var|
		data = {}

		define_method var do |*args|
			if args.length == 0
				data[var]
			else
				data[var] = (args.length > 1) ? args : args.first
			end
		end
	}
end

end; end
