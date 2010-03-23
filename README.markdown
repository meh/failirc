Fail IRC
======

Fail IRC is a Ruby (1.9+) library that implements and abstracts a Server and a Client.

Installation
------
Installation after cloning or downloading the source tree.

> $ gem build \*.gemspec
> \# gem install \*.gem

Installation from rubygems.org (not yet uploaded)
> \# gem install failirc

Server
------
Automatic encoding conversions, defaults to UTF-8. Choose the used encoding with the ENCODING command.
Highly modular and event driven. The RFC protocol is implemented in a module.
Optimized dispatching with Fibers, Threads and nonblocking I/O.
Supports SSL and creates automatically certificate and key if not given.
Easy to understand and edit XML configuration.

Client
------
Support for multiple servers and channels.
