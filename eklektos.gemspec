# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "eklektos/version"

Gem::Specification.new do |gem|
  gem.name        = "eklektos"
  gem.version     = Eklektos::VERSION
  gem.authors     = ["Joe Hosteny"]
  gem.email       = ["jhosteny@gmail.com"]
  gem.homepage    = "http://github.com/jhosteny/eklektos"
  gem.summary     = "A distributed leader election implementation running on DCell"
  gem.description = "Eklektos is a distributed leader election implementation described in the 'Omega Meet Paxos' paper by Malkhi, Oprea and Zhou"
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "dcell"
  gem.add_runtime_dependency "moneta"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
end
