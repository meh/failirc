Kernel.load 'lib/failirc/version.rb'

Gem::Specification.new {|s|
	s.name         = 'failirc'
	s.version      = IRC.version
	s.author       = 'meh.'
	s.email        = 'meh@paranoici.org'
	s.homepage     = 'http://github.com/meh/failirc'
	s.platform     = Gem::Platform::RUBY
	s.description  = 'A fail IRC library, Server and Client. Includes a working IRCd and IRCbot.'
	s.summary      = 'A fail IRC library.'
	s.files        = Dir.glob('lib/**/*.rb')
	s.require_path = 'lib'
	s.executables  = ['failircd', 'failbot']
	s.has_rdoc     = true

	s.add_dependency 'eventmachine'
	s.add_dependency 'call-me'
	s.add_dependency 'refining'
	s.add_dependency 'refr'
	s.add_dependency 'thread-extra'
}
