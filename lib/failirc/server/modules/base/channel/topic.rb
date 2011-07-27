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

module IRC; class Server; module Base; class Channel

class Topic
  extend Forwardable

  attr_reader    :channel, :text, :set_by
  attr_accessor  :set_on
  def_delegators :@channel, :server

  def initialize (channel)
    @channel = channel

    @semaphore = Mutex.new
  end

  def text= (value)
    @semaphore.synchronize {
      @text   = Reference.normalize(value)
      @set_on = Time.now
    }
  end

  def set_by= (value)
    if value.is_a?(Mask)
      @set_by = value
    else
      @set_by = value.mask.clone
    end
  end

  def to_s
    text
  end

  def nil?
    text.nil?
  end
end

end; end; end; end
