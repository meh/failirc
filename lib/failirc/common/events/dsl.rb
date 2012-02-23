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

module IRC; class Events

module DSL
	attr_reader :aliases, :chains, :custom

	def self.initialize (what)
		what.instance_eval do
			@aliases = Aliases.new
			@chains  = Chains.new
			@custom  = Custom.new
		end
	end

	def input (&block)
		tmp, @into = @into, :input

		self.instance_eval(&block)

		@into = tmp
	end

	def output (&block)
		tmp, @into = @into, :output

		instance_eval &block

		@into = tmp
	end

	def aliases (&block)
		return @aliases unless @into

		on = InsensitiveStruct.new
		on.instance_eval &block

		on.to_hash.each {|name, value|
			@aliases[@into][name] = value
		}
	end

	def default (options = {}, &block)
		return unless @into

		@chains[@into][:default] << Callback.new(options, &block)
	end

	def before (options = {}, &block)
		return unless @into

		@chains[@into][:before] << Callback.new(options, &block)
	end

	def after (options = {}, &block)
		return unless @into

		@chains[@into][:after] << Callback.new(options, &block)
	end

	def on (what, options = {}, &block)
		if @into
			@chains[@into][@aliases[@into][what] || what] << Callback.new(options, &block)
		else
			observe(what, options, &block)
		end
	end

	def observe (what, options = {}, &block)
		@custom[what] << Callback.new(options, &block)
	end

	def fire (what, *args, &block)
		if @owner
			@owner.fire(what, *args, &block)
		else
			catch(:halt) {
				Event.new(self, :custom, @custom[what]).call(*args, &block)
			}
		end
	end

	def skip
		throw :halt
	end
end

end; end
