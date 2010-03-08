Gem::Specification.new {|s|
    s.name              = 'failirc'
    s.version           = '0.0.1'
    s.author            = 'meh.'
    s.email             = 'meh.ffff@gmail.com'
    s.homepage          = 'http://meh.doesntexist.org/#failirc'
    s.platform          = Gem::Platform::RUBY
    s.description       = 'A fail IRC server library, and IRCd.'
    s.summary           = 'A fail IRC server library.'
    s.files             = Dir.glob('lib/**/*.rb')
    s.require_path      = 'lib'
    s.executables       = 'ircd'
    s.test_files        = []
    s.has_rdoc          = true
    s.extra_rdoc_files  = ['README']

    s.add_dependency('getopt')
}
