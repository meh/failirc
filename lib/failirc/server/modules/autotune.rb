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

version '0.0.1'

on :connect do
  server.workers.max = ((options[:minimum] || 10).to_i + server.clients.length / (options[:rate] || 10).to_i).to_i
end

on :disconnect do
  server.workers.max = ((options[:minimum] || 10).to_i + server.clients.length / (options[:rate] || 10).to_i).to_i
end
