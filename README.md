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

To automatically create factories for [Factory Girl][factory_girl] from models, somewhere in tests, use:

    # create default factories for all models
    Stepford::FactoryGirl.define_factories

or:

    Stepford::FactoryGirl.define_factories(:my_model_name_1, :my_model_name_2, :my_model_name_3)

TODO: need to somehow hook in so that we aren't overwriting other factories.

#### Machinist

Feel free to fork and add support.

### Configuration

    Stepford.configure do
      @debug = true
      @model_attr_match_test_data = {
        /|*.\_at,*.\_on,|/ => Time.now
      }
      @model_datatype_test_data = {
        string: lambda{|c|generate(:random_string)},
        integer: lambda{|c|Random.rand(9999)},
        decimal: lambda{|c|Random.rand(9999.9)},
        datetime: Time.now,
        timestamp: Time.now,
        time: Time.now,
        date: Time.now,
        binary: Random.bytes(8),
        boolean: true,
        xml: lambda{|c|"<test>#{generate(:random_string)}</test>"},
        ts_vector: nil
      }
    end

* debug is for debugging.
* attr_match_test_data is hash of regexp to match model column names.
* model_datatype_test_data is hash of regexp to match model column types.

### License

Copyright (c) 2012 Gary S. Weaver, released under the [MIT license][lic].

[factory_girl]: https://github.com/thoughtbot/factory_girl/
[lic]: http://github.com/garysweaver/restful_json/blob/master/LICENSE
