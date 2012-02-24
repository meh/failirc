Fail IRC
======
Fail IRC is a Ruby library that implements and abstracts a Server and a Client.

Both are implemented in an event driven, concurrent and modular way. You can easily write modules that can
do pretty much anything, in fact the standard protocols are implemented as modules.

There's still no documentation about the API and the events, but I will add it sooner or later. For the moment
just read the sources, they're pretty easy to understand (dispatcher excluded).

Server
------
- Automatic encoding conversions, defaults to UTF-8. Choose the used encoding with the ENCODING command.
- Highly modular and event driven. The RFC protocol is implemented in a module.
- Optimized dispatching with EventMachine.
- Supports SSL and creates automatically certificate and key if not given.
- Easy to understand and edit YAML configuration.

This server is not suitable for big networks, it obviously can't compare to the speed IRC daemons written in C,
but ease of scripting of failirc is also uncomparable to any of them.

If your network is small and you want to easily custom the server, this is for you.

Client
------
- Support for multiple servers and channels.
