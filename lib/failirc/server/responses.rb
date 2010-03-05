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

module IRC

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
    :text => '":#{(result) ? \\"#{value.nick}=#{(result.modes[:oper]) ? \'*\' : \'\'} = #{(!result.modes[:away]) ? \'+\' : \'-\'}#{value.user}@#{value.host}\\" : \'\'"'
}

# Reply format used by ISON to list replies to the query list.
RPL_ISON = {
    :code => 303,
    :text => '":#{(result) ? result.nick : ''}"'
}

RPL_AWWAY = {
    :code => 301,
    :text => '"#{value.nick} :#{value.away}"'
}

RPL_UNAWAY = {
    :code => 305,
    :text => '":You are no longer marked as being away"'
}

# These replies are used with the AWAY command (if allowed).
# RPL_AWAY is sent to any client sending a PRIVMSG to a client which is away.
# RPL_AWAY is only sent by the server to which the client is connected.
# Replies RPL_UNAWAY and RPL_NOWAWAY are sent when the client removes and sets an AWAY message.
RPL_NOWAWAY = {
    :code => 306,
    :text => '":You have been marked as being away"'
}

RPL_WHOISUSER = {
    :code => 311,
    :text => '"#{value.nick} #{value.user} #{value.host} * :#{value.realName}"'
}

RPL_WHOISSERVER = {
    :code => 312,
    :text => '"#{value.nick} #{value.server.host} :#{value.server.info}"'
}

RPL_WHOISOPERATOR = {
    :code => 313,
    :text => '"#{value.nick} :is an IRC operator"'
}

RPL_WHOISIDLE = {
    :code => 317,
    :text => '"#{value.nick} #{value.idle} :seconds idle"'
}

RPL_ENDOFWHOIS = {
    :code => 318,
    :text => '"#{value.nick} :End of /WHOIS list"'
}

# Replies 311 - 313, 317 - 319 are all replies generated in response to a WHOIS message.
# Given that there are enough parameters present, the answering server must either formulate a reply out of the above numerics (if the query nick is found) or return an error reply.
# The '*' in RPL_WHOISUSER is there as the literal character and not as a wild card.
# For each reply set, only RPL_WHOISCHANNELS may appear more than once (for long lists of channel names).
# The '@' and '+' characters next to the channel name indicate whether a client is a channel operator or has been granted permission to speak on a moderated channel.
# The RPL_ENDOFWHOIS reply is used to mark the end of processing a WHOIS message.
RPL_WHOISCHANNELS = {
    :code => 319,
    :text => '"#{value.nick} :#{value.channels.inspect(result)}"'
}

RPL_WHOWASUSER = {
    :code => 314,
    :text => '"#{value.nick} #{value.user} #{value.host} * :#{value.realName}"'
}

# When replying to a WHOWAS message, a server must use the replies RPL_WHOWASUSER, RPL_WHOISSERVER or ERR_WASNOSUCHNICK for each nickname in the presented list.
# At the end of all reply batches, there must be RPL_ENDOFWHOWAS (even if there was only one reply and it was an error).
RPL_ENDOFWHOWAS = {
    :code => 369,
    :text => '"#{value.nick} :End of WHOWAS"'
}

RPL_LISTSTART = {
    :code => 321,
    :text => '"Channel :Users Name"'
}

RPL_LIST = {
    :code => 322,
    :text => '"#{value.name} #{value.users.length} :#{value.topic}"'
}

# Replies RPL_LISTSTART, RPL_LIST, RPL_LISTEND mark the start, actual replies with data and end of the server's response to a LIST command.
# If there are no channels available to return, only the start and end reply must be sent.
RPL_LISTEND = {
    :code => 323,
    :text => '":End of /LIST"'
}

RPL_CHANNELMODEIS = {
    :code => 324,
    :text => '"#{value.name} #{value.modes}"'
}

RPL_NOTOPIC = {
    :code => 331,
    :text => '"#{value.name} :No topic is set"'
}

# When sending a TOPIC message to determine the channel topic, one of two replies is sent.
# If the topic is set, RPL_TOPIC is sent back else RPL_NOTOPIC.
RPL_TOPIC = {
    :code => 332,
    :text => '"#{value.channel.name} :#{value}"'
}

# Returned by the server to indicate that the attempted INVITE message was successful and is being passed onto the end client.
RPL_INVITING = {
    :code => 341,
    :text => '"#{target.channel} #{target.nick}"'
}

# Returned by a server answering a SUMMON message to indicate that it is summoning that user.
RPL_SUMMONING = {
    :code => 342,
    :text => '"#{value.user} :Summoning user to IRC"'
}

# Reply by the server showing its version details.
# The <version> is the version of the software being used (including any patchlevel revisions) and the <debuglevel> is used to indicate if the server is running in "debug mode".
# The "comments" field may contain any comments about the version or further version details.
RPL_VERSION = {
    :code => 351,
    :text => '"failirc-#{server.version}. #{server.host} :THE GAME"'
}

RPL_WHOREPLY = {
    :code => 352,
    :text => '"#{value[:channel].name} #{value[:user].user} #{value[:user].host} #{value[:user].server.host} #{value[:user].nick} #{\'H\' || \'G\'}#{value[:user].modes[:level]} :#{value[:hops]} #{value[:user].realName}"'
}

# The RPL_WHOREPLY and RPL_ENDOFWHO pair are used to answer a WHO message.
# The RPL_WHOREPLY is only sent if there is an appropriate match to the WHO query.
# If there is a list of parameters supplied with a WHO message, a RPL_ENDOFWHO must be sent after processing each list item with <name> being the item.
RPL_ENDOFWHO = {
    :code => 315,
    :text => '"#{value} :End of /WHO list"'
}

RPL_NAMREPLY = {
    :code => 353,
    :text => '"= #{value.name} :#{value.users.inspect(true)}"'
}

# To reply to a NAMES message, a reply pair consisting of RPL_NAMREPLY and RPL_ENDOFNAMES is sent by the server back to the client.
# If there is no channel found as in the query, then only RPL_ENDOFNAMES is returned.
# The exception to this is when a NAMES message is sent with no parameters and all visible channels and contents are sent back in a series of RPL_NAMEREPLY messages with a RPL_ENDOFNAMES to mark the end.
RPL_ENDOFNAMES = {
    :code => 366,
    :text => '"#{value} :End of /NAMES list"'
}

RPL_LINKS = {
    :code => 364,
    :text => '"#{value.mask} #{value.host} :#{message.hopcount} #{value.informations}"'
}

# In replying to the LINKS message, a server must send replies back using the RPL_LINKS numeric and mark the end of the list using an RPL_ENDOFLINKS reply.v 
RPL_ENDOFLINKS = {
    :code => 365,
    :text => '"#{value.mask} :End of /LINKS list"'
}

RPL_BANLIST = {
    :code => 367,
    :text => '"#{value}"'
}

# When listing the active 'bans' for a given channel, a server is required to send the list back using the RPL_BANLIST and RPL_ENDOFBANLIST messages.
# A separate RPL_BANLIST is sent for each active banid. After the banids have been listed (or if none present) a RPL_ENDOFBANLIST must be sent.
RPL_ENDOFBANLIST = {
    :code => 368,
    :text => '"#{value} :End of channel ban list"'
}

RPL_INFO = {
    :code => 371,
    :text => '":#{value}"'
}

# A server responding to an INFO message is required to send all its 'info' in a series of RPL_INFO messages with a RPL_ENDOFINFO reply to indicate the end of the replies.
RPL_ENDOFINFO = {
    :code => 374,
    :text => '":End of /INFO list"'
}

RPL_MOTDSTART = {
    :code => 375,
    :text => '":- #{server.host} Message of the day - "'
}

RPL_MOTD = {
    :code => 372,
    :text => '":- #{value}"'
}

# When responding to the MOTD message and the MOTD file is found, the file is displayed line by line, with each line no longer than 80 characters, using RPL_MOTD format replies.
# These should be surrounded by a RPL_MOTDSTART (before the RPL_MOTDs) and an RPL_ENDOFMOTD (after).
RPL_ENDOFMOTD = {
    :code => 376,
    :text => '":End of /MOTD command"'
}

# RPL_YOUREOPER is sent back to a client which has just successfully issued an OPER message and gained operator status.
RPL_YOUREOPER = {
    :code => 381,
    :text => '":You are now an IRC operator"'
}

# If the REHASH option is used and an operator sends a REHASH message, an RPL_REHASHING is sent back to the operator.
RPL_REHASHING = {
    :code => 382,
    :text => '"#{value.path} :Rehashing"'
}

# When replying to the TIME message, a server must send the reply using the RPL_TIME format above.
# The string showing the time need only contain the correct day and time there.
# There is no further requirement for the time string.
RPL_TIME = {
    :code => 391,
    :text => '"#{value.host} :#{value.time}"'
}

RPL_USERSSTART = {
    :code => 392,
    :text => '":UserID Terminal Host"'
}

RPL_USERS = {
    :code => 393,
    :text => '":%-8s %-9s %-8s"'
}

RPL_ENDOFUSERS = {
    :code => 394,
    :text => '":End of users"'
}

# If the USERS message is handled by a server, the replies RPL_USERSTART, RPL_USERS, RPL_ENDOFUSERS and RPL_NOUSERS are used.
# RPL_USERSSTART must be sent first, following by either a sequence of RPL_USERS or a single RPL_NOUSER.
# Following this is RPL_ENDOFUSERS.
RPL_NOUSERS = {
    :code => 395,
    :text => '":Nobody logged in"'
}

RPL_TRACELINK = {
    :code => 200,
    :text => '"Link #{value.version} #{value.debugLevel} #{value.destination} #{value.next.host}"'
}

RPL_TRACECONNECTING = {
    :code => 201,
    :text => '"Try. #{value.class} #{value.host}"'
}

RPL_TRACEHANDSHAKE = {
    :code => 202,
    :text => '"H.S. #{value.class} #{value.host}"'
}

RPL_TRACEUNKNOWN = {
    :code => 203,
    :text => '"???? #{value.class} #{value.ip}"'
}

RPL_TRACEOPERATOR = {
    :code => 204,
    :text => '"Oper #{value.class} #{value.nick}"'
}

RPL_TRACEUSER = {
    :code => 205,
    :text => '"User #{value.class} #{value.nick}"'
}

RPL_TRACESERVER = {
    :code => 206,
    :text => '"Serv #{value.class} <int>S <int>C <server> <nick!user|*!*>@<host|server>"'
}

# custom
RPL_WELCOME = {
    :code => 1,
    :text => '":Welcome to the #{server.config.elements[\'config/server/name\'].text} #{value.mask}"'
}

RPL_HOSTEDBY = {
    :code => 2,
    :text => '":Your host is #{server.host}[#{server.ip}/#{value.listen.attributes[\'port\']}], running version failirc-#{server.version}"'
}

RPL_SERVCREATEDON = {
    :code => 3,
    :text => '":This server was created #{server.createdOn}"'
}

RPL_CHANCREATEDON = {
    :code => 329,
    :text => '"#{value.name} #{value.createdOn.tv_sec}"'
}

RPL_TOPICSETON = {
    :code => 333,
    :text => '"#{value.channel.name} #{value.setBy.client} #{value.setOn.tv_sec}"'
}

end
