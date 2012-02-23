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

require 'failirc/common/events/event'
require 'failirc/common/events/callback'
require 'failirc/common/events/dsl'

require 'failirc/common/events/aliases'
require 'failirc/common/events/chains'
require 'failirc/common/events/custom'

module IRC

class Events
	attr_reader :server, :aliases, :chains

	def initialize (server)
		@server = server

		DSL.initialize(self)

		@hooks = []
	end

	def hook (mod)
		@hooks << mod
	end

	def alias (chain, name, value = nil)
		if value
			@aliases[chain][name.to_sym.downcase] = value
		else
			@aliases[chain][name.to_sym.downcase] || @hooks.find {|hook|
				hook.aliases[chain][name]
			}
		end
	end

	# WARNING: brace for legacy shitty code, I don't even understand it anymore.
	def event (chain, what)
		if what.is_a?(Symbol)
			Event.new(self, chain, (@chains[chain][what] + @hooks.map {|hook| hook.chains[chain][what]}).flatten.compact, [what])
		else
			callbacks = Hash.new { |h, k| h[k] = [] }

			(@hooks + [self]).each {|hook|
				hook.chains[chain].each {|key, value|
					callbacks[key].insert(-1, *value)
				}
			}

			regexps, callbacks = callbacks.to_a.select {|(name, callbacks)|
				!name.is_a?(Symbol)
			}.select {|(regexp, callbacks)|
				what.to_s.match(regexp) rescue false
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

			Event.new(self, chain, [callbacks].flatten.compact, aliases)
		end
	end

	def dispatch (chain, thing, string)
		return unless thing

		current = event(chain, string).on(thing, string)

		catch(:halt) {
			event(chain, :before).call(current, thing, string)

			unless current.callbacks.empty?
				current.call
			else
				event(chain, :default).call(current, thing, string)
			end

			event(chain, :after).call(current, thing, string)
		}
	end

	def register (chain, what, options={}, &block)
		@chains[chain][what] << Callback.new(options, &block)
	end

	def observe (what, options={}, &block)
		@custom[what] << Callback.new(options, &block)
	end

	def fire (what, *args, &block)
		catch(:halt) {
			Event.new(self, :custom, (@custom[what] + @hooks.map {|hook| hook.custom[what] }).flatten.compact).call(*args, &block)
		}
	end
end

end
