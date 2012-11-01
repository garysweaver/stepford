Stepford
=====

*This is untested and under construction. Hoping to spend more time on it later...*

### Setup

In your Rails 3+ project, add this to your Gemfile:

    gem 'stepford', :git => 'git://github.com/garysweaver/stepford.git'

Then run:

    bundle install

### Usage

#### Factory Girl

To automatically generate factories for [Factory Girl][factory_girl] from models, type this at command-line:

    bundle exec stepford factories

That will create a `test/factories` directory and put a `some_model.rb` for each model into it with a starter FactoryGirl factory definition that may or may not work for you.

Or, to generate a single file with all factories in `spec/factories.rb`, you'd use:

    bundle exec stepford factories --single --path spec

Or it will figure it out yourself that you want a single file if the path ends in `.rb`:

    bundle exec stepford factories --path spec/support/factories.rb

### License

Copyright (c) 2012 Gary S. Weaver, released under the [MIT license][lic].

[factory_girl]: https://github.com/thoughtbot/factory_girl/
[lic]: http://github.com/garysweaver/stepford/blob/master/LICENSE
