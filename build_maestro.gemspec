# -*- encoding: utf-8 -*-
require File.expand_path('../lib/build_maestro/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Scott A. Guyer"]
  gem.email         = ["saguyer@gmail.com"]
  gem.description   = %q{This is a simple build automation tool utilizing a simple DSL for specifying builds}
  gem.summary       = %q{Build automation tool}
  gem.homepage      = ""
  gem.files         = [
    'lib/build_dsl.rb',
    'lib/build_maestro/svn.rb',
    'lib/build_maestro/version.rb'
  ]
  gem.executables   = [ "build_maestro" ]
  gem.name          = "build_maestro"
  gem.require_paths = ["lib"]
  gem.version       = BuildMaestro::VERSION
end
