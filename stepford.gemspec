# -*- encoding: utf-8 -*-  
$:.push File.expand_path("../lib", __FILE__)  
require "stepford/version" 

Gem::Specification.new do |s|
  s.name        = 'stepford'
  s.version     = Stepford::VERSION
  s.authors     = ['Gary S. Weaver']
  s.email       = ['garysweaver@gmail.com']
  s.homepage    = 'https://github.com/garysweaver/stepford'
  s.summary     = %q{The land of Stepford comes to your Ruby testing.}
  s.description = %q{See the README. It's more up-to-date.}
  s.files = Dir['lib/**/*'] + ['Rakefile', 'README.md']
  s.license = 'MIT'
  s.add_runtime_dependency 'activerecord'
  s.add_runtime_dependency 'factory_girl'
end
