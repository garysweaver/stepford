require 'rake/testtask'

#http://nicksda.apotomo.de/2010/10/testing-your-rails-3-engine-sitting-in-a-gem/
Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end

desc "Run tests"
task :default => :test
