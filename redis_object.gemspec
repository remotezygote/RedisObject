# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "redis_object/version"

Gem::Specification.new do |s|
  s.name        = "redis_object"
  s.version     = Seabright::RedisObject::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["John Bragg"]
  s.email       = ["john@seabrightstudios.com"]
  s.homepage    = ""
  s.summary     = %q{Maps arbitrary objects to a Redis store with indices and smart retrieval and storage mechanisms.}
  s.description = %q{}

  s.rubyforge_project = "redis_object"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.add_dependency "redis"
  s.add_dependency "yajl-ruby"
  s.add_dependency "activesupport"
  s.add_dependency "extensions", ">= 0.6.2"
end
