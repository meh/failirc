Fail IRC
======
Fail IRC is a Ruby library that implements and abstracts a Server and a Client.

Both are implemented in an event driven, concurrent and modular way. You can easily write modules that can
do pretty much anything, in fact the standard protocols are implemented as modules.

There's still no documentation about the API and the events, but I will add it sooner or later. For the moment
just read the sources, they're pretty easy to understand (dispatcher excluded).

Installation
------
Installation after cloning or downloading the source tree.

    $ gem build *.gemspec
    # gem install *.gem

Installation from rubygems.org (not yet uploaded)

    # gem install failirc

Server
------
- Automatic encoding conversions, defaults to UTF-8. Choose the used encoding with the ENCODING command.
- Highly modular and event driven. The RFC protocol is implemented in a module.
- Optimized dispatching with Fibers, Threads and nonblocking I/O.
- Supports SSL and creates automatically certificate and key if not given.
- Easy to understand and edit XML configuration.

Client
------
- Support for multiple servers and channels.
