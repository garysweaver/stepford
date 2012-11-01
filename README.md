Stepford
=====

Stepford is a CLI to create starter [Factory Girl][factory_girl] factories for all of your Rails models.

### Setup

In your Rails 3+ project, add this to your Gemfile:

    gem 'stepford'

Then run:

    bundle install

### Usage

#### Factory Girl

The default will assume a `test/factories` directory exists and that it should create a factory file for each model:

    bundle exec stepford factories

To put all of your factories into `spec/factories.rb`:

    bundle exec stepford factories --single --path spec

It will figure out that you want a single file, if the path ends in `.rb`:

    bundle exec stepford factories --path spec/support/factories.rb

### Stepford Checks Model Associations

Stepford first loads Rails and attempts to check your models for broken associations.

If associations are deemed broken, it will output proposed changes.

### Troubleshooting

If you have duplicate factory definitions during Rails load, it may complain. Just move, rename, or remove the offending files and factories and retry.

Uses the Ruby 1.9 hash syntax in generated factories. If you don't have 1.9, it might not fail during generation, but it may later when loading the factories.

### License

Copyright (c) 2012 Gary S. Weaver, released under the [MIT license][lic].

[factory_girl]: https://github.com/thoughtbot/factory_girl/
[lic]: http://github.com/garysweaver/stepford/blob/master/LICENSE
