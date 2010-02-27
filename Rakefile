require 'rake'
require 'rake/clean'
require 'rake/gempackagetask'

CLEAN.include("pkg")

specification = Gem::Specification.new do |specification|
    specification.name             = "failirc"
    specification.version          = "0.0.1"
    specification.author           = "meh."
    specification.email            = "meh.ffff@gmail.com"
    specification.homepage         = "http://meh.doesntexist.org/#failirc"
    specification.platform         = Gem::Platform::RUBY
    specification.description      = "A fai IRC server library, and IRCd."
    specification.summary          = "A fail IRC server library."
    specification.files            = FileList["{bin,lib,etc}/**/*"].to_a
    specification.require_path     = "lib"
    specification.test_files       = []
    specification.has_rdoc         = true
    specification.extra_rdoc_files = ["README"]
end

task :default => [:repackage]

Rake::GemPackageTask.new(specification) do |pkg| 
    pkg.need_tar = true
end 
