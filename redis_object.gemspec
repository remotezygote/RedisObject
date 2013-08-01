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
  s.required_ruby_version = '>= 1.9.2'
  s.add_dependency "utf8_utils", ">= 2.0.1"
  s.add_dependency "redis", ">= 3.0.4"
  s.add_dependency "yajl-ruby", ">= 1.1.0"
  s.add_dependency "activesupport", ">= 3.2.13"
  s.add_dependency "psych", ">= 1.3.4"
  s.add_dependency "defined"
end
