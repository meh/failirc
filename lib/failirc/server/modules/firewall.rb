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

require 'failirc/module'

module IRC; class Server

Module.define('firewall', '0.0.1') {
  on start do
    @log = options[:file] ? File.open(options[:file]) : $stdout
  end

  on stop do
    @log.close
  end

  on log do |string|
    @log.puts "[#{Time.now}] #{string}"
    @log.flush
  end

  def dispatch (event, thing, string)
    server.fire :log, "#{thing.inspect} #{(event.chain == :input) ? '*IN* ' : '*OUT*'} #{string.inspect}"
  end

  input  { before -1234567890, &method(:dispatch) }
  output { after   1234567890, &method(:dispatch) }

  on killed do |thing, message|
    server.fire :log, "#{thing.inspect} KILL :#{message}"
  end
}

end; end
