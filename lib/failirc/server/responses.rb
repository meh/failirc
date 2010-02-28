# failirc, a fail IRC server.
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

# Dummy reply number. Not used.
RPL_NONE = {
    :code => 300,
    :text => '""'
}

# Reply format used by USERHOST to list replies to the query list. The reply string is composed as follows:
# <reply> ::= <nick>['*'] '=' <'+'|'-'><hostname>
# The '*' indicates whether the client has registered as an Operator.
# The '-' or '+' characters represent whether the client has set an AWAY message or not respectively.
RPL_USERHOST = {
    :code => 302,
    :text => '":#{server.name} #{code} #{user.nick} :#{(result) ? \\"#{result.nick}=#{(result.oper?) ? \'*\' : \'\'} = #{(!result.away?) ? \'+\' : \'-\'}#{result.username}@#{result.hostname}\\" : \'\'"'
}

# Reply format used by ISON to list replies to the query list.
RPL_ISON = {
    :code => 303,
    :text => '":#{server.name} #{code} #{user.nick} :#{(result) ? result.nick : ''}"'
}
