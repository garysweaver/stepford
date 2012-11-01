# -*- encoding: utf-8 -*-  
$:.push File.expand_path("../lib", __FILE__)  
require "stepford/version" 

Gem::Specification.new do |s|
  s.name        = 'stepford'
  s.version     = Stepford::VERSION
  s.authors     = ['Gary S. Weaver']
  s.email       = ['garysweaver@gmail.com']
  s.homepage    = 'https://github.com/garysweaver/stepford'
  s.summary     = %q{Autocreate FactoryGirl factories from models.}
  s.description = %q{A CLI to create starter FactoryGirl factories for all of your Rails models.}
  s.files = Dir['lib/**/*'] + ['Rakefile', 'README.md']
  s.license = 'MIT'
  s.add_dependency 'thor'
  s.add_runtime_dependency 'rails'
  s.executables = %w(stepford)
  s.require_paths = ["lib"]
end
