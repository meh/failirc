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

module IRC; class Server; module Base

module Incoming; def self.extended (obj)
  obj.refine_method :send do |old, *args|
    if args.first.is_a?(String)
      old.call(args.first)
    else
      response, value = args

      begin
        old.call ":#{server.host} #{'%03d' % response[:code]} #{identifier} #{response[:text].interpolate(binding)}"
      rescue Exception => e
        IRC.debug response[:text]
        raise e
      end
    end
  end

  obj.refine_method :identifier do
    'faggot'
  end
end; end

end; end; end
