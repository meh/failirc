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

# Used to indicate the nickname parameter supplied to a command is currently unused.
ERR_NOSUCHNICK = {
    :code => 401,
    :text => '"#{value} :No such nick/channel"'
}

# Used to indicate the server name given currently doesn't exist.
ERR_NOSUCHSERVER = {
    :code => 402,
    :text => '"#{value} :No such server"'
}

# Used to indicate the given channel name is invalid.
ERR_NOSUCHCHANNEL = {
    :code => 403,
    :text => '"#{value} :No such channel"'
}

# Sent to a user who is either (a) not on a channel which is mode +n or (b) not a chanop (or mode +v) on a channel which has mode +m set and is trying to send a PRIVMSG message to that channel.
ERR_CANNOTSENDTOCHAN = {
    :code => 404,
    :text => '"#{value} :Cannot send to channel "'
}

ERR_YOUNEEDVOICE = {
    :code => 404,
    :text => '"#{value} :You need voice (+v) (#{value})"'
}

ERR_NOEXTERNALMESSAGES = {
    :code => 404,
    :text => '"#{value} :No external channel messages (#{value})"'
}

ERR_YOUAREBANNED = {
    :code => 404,
    :text => '"#{value} :You are banned (#{value})"'
}

# Sent to a user when they have joined the maximum number of allowed channels and they try to join another channel.
ERR_TOOMANYCHANNELS = {
    :code => 405,
    :text => '"#{value.name} :You have joined too many channels"'
}

# Sent to a user when they have joined the maximum number of allowed channels and they try to join another channel.
ERR_WASNOSUCHNICK = {
    :code => 406,
    :text => '"#{value} :There was no such nickname"'
}

# Returned to a client which is attempting to send PRIVMSG/NOTICE using the user@host destination format and for a user@host which has several occurrences.
ERR_TOOMANYTARGETS = {
    :code => 407,
    :text => '"#{value} :Duplicate recipients. No message delivered"'
}

# PING or PONG message missing the originator parameter which is required since these commands must work without valid prefixes.
ERR_NOORIGIN = {
    :code => 409,
    :text => '":No origin specified"'
}

ERR_NORECIPIENT = {
    :code => 411,
    :text => '":No recipient given (#{value})"'
}

ERR_NOTEXTTOSEND = {
    :code => 412,
    :text => '":No text to send"'
}

ERR_NOTOPLEVEL = {
    :code => 413,
    :text => '"#{mask} :No toplevel domain specified"'
}

# 412 - 414 are returned by PRIVMSG to indicate that the message wasn't delivered for some reason. ERR_NOTOPLEVEL and ERR_WILDTOPLEVEL are errors that are returned when an invalid use of "PRIVMSG $<server>" or "PRIVMSG #<host>" is attempted.
ERR_WILDTOPLEVEL = {
    :code => 414,
    :text => '"#{mask} :Wildcard in toplevel domain"'
}

# Returned to a registered client to indicate that the command sent is unknown by the server.
ERR_UNKNOWNCOMMAND = {
    :code => 421,
    :text => '"#{value} :Unknown command"'
}

# Server's MOTD file could not be opened by the server.
ERR_NOMOTD = {
    :code => 422,
    :text => '":MOTD File is missing"'
}

# Returned by a server in response to an ADMIN message when there is an error in finding the appropriate information.
ERR_NOADMININFO = {
    :code => 423,
    :text => '"#{server.name} :No administrative info available"'
}

# Generic error message used to report a failed file operation during the processing of a message.
ERR_FILEERROR = {
    :code => 424,
    :text => '":File error doing #{fileOperation} on #{file}"'
}

# Returned when a nickname parameter expected for a command and isn't found.
ERR_NONICKNAMEGIVEN = {
    :code => 431,
    :text => '":No nickname given"'
}

# Returned after receiving a NICK message which contains characters which do not fall in the defined set. See section x.x.x for details on valid nicknames.
ERR_ERRONEUSNICKNAME = {
    :code => 432,
    :text => '"#{value} :Erroneus nickname"'
}

# Returned when a NICK message is processed that results in an attempt to change to a currently existing nickname.
ERR_NICKNAMEINUSE = {
    :code => 433,
    :text => '"#{value} :Nickname is already in use"'
}

# Returned by a server to a client when it detects a nickname collision (registered of a NICK that already exists by another server).
ERR_NICKCOLLISION = {
    :code => 436,
    :text => '"#{value} :Nickname collision KILL"'
}

# Returned by the server to indicate that the target user of the command is not on the given channel.
ERR_USERNOTINCHANNEL = {
    :code => 441,
    :text => '"#{value[:nick]} #{value[:channel]} :They aren\'t on that channel"'
}

# Returned by the server whenever a client tries to perform a channel effecting command for which the client isn't a member.
ERR_NOTONCHANNEL = {
    :code => 442,
    :text => '"#{value} :You\'re not on that channel"'
}

# Returned when a client tries to invite a user to a channel they are already on.
ERR_USERONCHANNEL = {
    :code => 443,
    :text => '"#{user} #{channel.name} :is already on channel"'
}

# Returned by the summon after a SUMMON command for a user was unable to be performed since they were not logged in.
ERR_NOLOGIN = {
    :code => 444,
    :text => '"#{user} :User not logged in"'
}

# Returned as a response to the SUMMON command. Must be returned by any server which does not implement it.
ERR_SUMMONDISABLED = {
    :code => 445,
    :text => '":SUMMON has been disabled"'
}

# Returned as a response to the USERS command. Must be returned by any server which does not implement it.
ERR_USERSDISABLED = {
    :code => 446,
    :text => '":USERS has been disabled"'
}

# Returned by the server to indicate that the client must be registered before the server will allow it to be parsed in detail.
ERR_NOTREGISTERED = {
    :code => 451,
    :text => '":You have not registered"'
}

# Returned by the server by numerous commands to indicate to the client that it didn't supply enough parameters.
ERR_NEEDMOREPARAMS = {
    :code => 461,
    :text => '"#{value} :Not enough parameters"'
}

# Returned by the server to any link which tries to change part of the registered details (such as password or user details from second USER message).
ERR_ALREADYREGISTRED = {
    :code => 462,
    :text => '":You may not reregister"'
}

# Returned to a client which attempts to register with a server which does not been setup to allow connections from the host the attempted connection is tried.
ERR_NOPERMFORHOST = {
    :code => 463,
    :text => '":Your host isn\'t among the privileged"'
}

# Returned to indicate a failed attempt at registering a connection for which a password was required and was either not given or incorrect.
ERR_PASSWDMISMATCH = {
    :code => 464,
    :text => '":Password incorrect"'
}

# Returned after an attempt to connect and register yourself with a server which has been setup to explicitly deny connections to you.
ERR_YOUREBANNEDCREEP = {
    :code => 465,
    :text => '":You are banned from this server"'
}

ERR_KEYSET = {
    :code => 467,
    :text => '"#{channel.name} :Channel key already set"'
}

ERR_CHANNELISFULL = {
    :code => 471,
    :text => '"#{channel.name} :Cannot join channel (+l)"'
}

ERR_UNKNOWNMODE = {
    :code => 472,
    :text => '"#{value} :is unknown mode char to me"'
}

ERR_INVITEONLYCHAN = {
    :code => 473,
    :text => '"#{channel.name} :Cannot join channel (+i)"'
}

ERR_BANNEDFROMCHAN = {
    :code => 474,
    :text => '"#{channel.name} :Cannot join channel (+b)"'
}

ERR_BADCHANNELKEY = {
    :code => 475,
    :text => '"#{channel.name} :Cannot join channel (+k)"'
}

# Any command requiring operator privileges to operate must return this error to indicate the attempt was unsuccessful.
ERR_NOPRIVILEGES = {
    :code => 481,
    :text => '":Permission Denied- You\'re not an IRC operator"'
}

# Any command requiring 'chanop' privileges (such as MODE messages) must return this error if the client making the attempt is not a chanop on the specified channel.
ERR_CHANOPRIVSNEEDED = {
    :code => 482,
    :text => '"#{value} :You\'re not channel operator"'
}

# Any attempts to use the KILL command on a server are to be refused and this error returned directly to the client.
ERR_CANTKILLSERVER = {
    :code => 483,
    :text => '":You cant kill a server!"'
}

# If a client sends an OPER message and the server has not been configured to allow connections from the client's host as an operator, this error must be returned.
ERR_NOOPERHOST = {
    :code => 491,
    :text => '":No O-lines for your host"'
}

# Returned by the server to indicate that a MODE message was sent with a nickname parameter and that the a mode flag sent was not recognized.
ERR_UMODEUNKNOWNFLAG = {
    :code => 501,
    :text => '":Unknown MODE flag"'
}

# Error sent to any user trying to view or change the user mode for a user other than themselves.
ERR_USERSDONTMATCH = {
    :code => 502,
    :text => '":Cant change mode for other users"'
}

# custom
ERR_BADCHANMASK = {
    :code => 476,
    :text => '"#{value} :Bad channel name"'
}

end
