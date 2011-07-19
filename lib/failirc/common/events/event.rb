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

class Event
  attr_reader :owner, :chain, :name, :callbacks, :aliases, :thing, :string

  def initialize (owner, chain, callbacks=[], aliases=[])
    @owner   = owner
    @chain   = chain
    @aliases = aliases

    @callbacks = callbacks.sort
  end

  def on (thing, string)
    @thing  = thing
    @string = string

    self
  end

  def alias? (name)
    @aliases.member?(name.to_s.downcase.to_sym)
  end

  def call (*args, &block)
    @callbacks.each {|callback|
      begin
        if @thing && @string && args.empty?
          callback.call(Reference[@thing], Reference[@string])
        else
          callback.call(*args.map {|arg| Reference[arg]}, &block)
        end
      rescue LocalJumpError; end
    }
  end
end

end; end
