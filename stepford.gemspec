# -*- encoding: utf-8 -*-  
$:.push File.expand_path("../lib", __FILE__)  
require "stepford/version" 

Gem::Specification.new do |s|
  s.name        = 'stepford'
  s.version     = Stepford::VERSION
  s.authors     = ['Gary S. Weaver']
  s.email       = ['garysweaver@gmail.com']
  s.homepage    = 'https://github.com/garysweaver/stepford'
  s.summary     = %q{FactoryGirl becomes easier and automated.}
  s.description = %q{Automates FactoryGirl deep creation of models and their required associations avoiding circulars and provides a generator for FactoryGirl factories that reflects on models.}
  s.files = Dir['lib/**/*'] + ['Rakefile', 'README.md']
  s.license = 'MIT'
  s.add_dependency 'thor'
  s.add_runtime_dependency 'rails'
  s.executables = %w(stepford)
  s.require_paths = ["lib"]
end
