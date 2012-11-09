Stepford
=====

Stepford is an automatic required (non-null or presence validated) association resolving (creating/building/stubbing) wrapper and/or factory generator for [FactoryGirl][factory_girl].

For example, with the rspec helper:

    create(:foo)

Would take a :foo FactoryGirl factory that has no associations defined in it (only required attributes) and will travel the dependency tree of the models to create and create_list as needed. Or, you can build the same way:

    build(:foo)

Need to just customize a few things? You can use the normal FactoryGirl behavior (args, options, block) but also specify options for each factory.

e.g. maybe Bar has a required association called house_special which uses the :beer factory, and we have a block we want to send into it; oh, and Beer has specials that you want to build as a list of 3 using the :tuesday_special_offer factory. Just set it up like:

    Stepford::FactoryGirl.create_list(:bar, with_factory_options: {
      house_special: [:create, :beer, {blk: ->(beer) do; beer.bubbles.create(attributes_for(:bubbles)); end}],
      specials: [:build_list, :tuesday_special_offer, 3]
    }) do
      # any block you would send to FactoryGirl.create_list(:bar) would go here
    end

What if you have an existing schema, and you want to use FactoryGirl, but don't have any factories yet?

The Stepford CLI allows you to generate your factories.rb or multiple factory files for you.

e.g. maybe one of your models is called post, then you could generate a factory for post and all of the other models with a one-liner, maybe with the following in the `some/path/factories/post.rb` file:

    require 'factory_girl_rails'

    FactoryGirl.define do
    
      factory :post do
        author
        association :edited_by, factory: :user
        FactoryGirl.create_list :comments, 2
        trait :with_notes do; FactoryGirl.create_list :note, 2; end
        trait :complete do; complete true; end
        trait :not_complete do; complete false; end
        created_at { 2.weeks.ago }
        name 'Test Name'
        price 1.23
        trait :with_summary do; template 'Test Summary'; end
        updated_at { 2.weeks.ago }
      end

    end

### Setup

In your Rails 3+ project, add this to your Gemfile:

    gem 'stepford'

If you don't already have it, add this also:

    gem 'factory_girl_rails'

Then run:

    bundle install

### Usage

#### Require

Put this in your `test/spec_helper.rb`, `spec/spec_helper.rb`, or some other file used by your tests:

    require 'stepford/factory_girl'

#### Stepford::FactoryGirl

Stepford::FactoryGirl acts just like FactoryGirl, but it goes through all the null=false associations for foreign keys that aren't primary keys in the factory and/or its presence validated associations and attempts to create/build/build_stub depending on what you called originally, but also lets you pass in an `:with_factory_options` that can contain a hash of factory name symbols to the arguments and block you'd pass to it. You specify the block using a `:blk` option with a proc/lambda (probably a lambda) to use in that method.

If you don't specify options, it's easy (note: it is even easier with the rspec helper- see below). If Foo requires Bar and Bar requires a list of Foobars and a Barfoo, and you have factories for each of those, you'd only have to do:

    Stepford::FactoryGirl.create_list(:foo, 5)

and that would create a list of 5 Foos, that each have a Bar, where each Bar has a list of 2 Foobars and a Barfoo. Easy!

But, you might want to specify traits, and certain attributes or associations or a block or different methods to use. That's pretty easy, too. Let's say you only need to tweak bar and foobar on each item, but the rest gets created as it would with just `Stepford::FactoryGirl.create_list`, so if you wanted to create 5 with two traits `:fancy` and `:light` and only build the bar and build bar's foobar as a stub:

    Stepford::FactoryGirl.create_list(:foo, 5, :fancy, :light, with_factory_options: {
      bar: [:build, :bar],
      foobar: [:build_stubbed, :foobar]
    }) do
      # any block you would send to FactoryGirl.create_list(:foo) would go here
    end

##### RSpec Helpers

Put this in your `spec/spec_helper.rb`:

    require 'stepford/factory_girl_rspec_helpers'

Then you can just use `deep_create`, `deep_create_list`, `deep_build`, `deep_build_list`, or `deep_build_stubbed` in your rspec tests (`deep_create` becomes a shortcut for `::Stepford::FactoryGirl.create`, etc.), e.g.:

    deep_create(:foo)

##### Stopping Circular References

If you have a circular reference (A has NOT NULL foreign key to B that has NOT NULL foreign key to C that has NOT NULL foreign key to A) either via schema where the foreign key is not also a primary key of the model with the belongs_to, or there is an ActiveRecord presence validation), there is a workaround. First, prepopulate one of the models involved in the interdependency chain in the database as part of test setup, or if the ids are NOT NULL but are not foreign key constrained (i.e. if you can enter an invalid ID into the foreign key column, which implies possible referential integrity issues) then you may be able to set them with an invalid id. Take that foreign id and then use the following to ensure that it will set that foreign id or instance. This is done at a global level which may not work for you, but it makes it convenient to put into your spec/spec_helper.rb, etc. For example, let's say your bar has NOT NULL on bartender_id and waiter_id, and in turn bartender and waiter both have a NOT NULL bar_id, and neither enforce foreign keys. Maybe you have preloaded data for waiter somehow as the id '123', but want to set bartender to just use an invalid id '-1', and you want to do it when they are on their second loop. You could use:

    Stepford::FactoryGirl.stop_circular_refs = {
       [:bartender, :bar] => {on_loop: 2, set_foreign_key_to: -1},
       [:waiter, :bar] => {on_loop: 2, set_to: Waiter.find(123)},
    }

##### Debugging

Add somewhere after the require:

    Stepford::FactoryGirl.debug = true

#### CLI

Stepford has a CLI with a circular reference checker and a generator to automatically create your factories file(s).

##### Refs

Check ActiveRecord circular dependencies where the foreign key for a belongs_to is not also a primary key of the model, or there is an ActiveRecord presence validation keeping an association from being null:

    bundle exec stepford circular

Then it outputs the circular dependencies, e.g.:

    The following non-nullable foreign keys used in ActiveRecord model associations are involved in circular dependencies:

    beers.waitress_id -> waitresses.bartender_id -> bartenders.beer_id -> beers.waitress_id

    beers.waitress_id -> waitresses.bartender_id -> bartenders.order_id -> order.beer_id -> beers.waitress_id


    Distinct foreign keys involved in a circular dependency:

    beers.waitress_id
    order.beer_id
    bartenders.beer_id
    bartenders.order_id
    waitresses.bartender_id


    Foreign keys by number of circular dependency chains involved with:

    2 (out of 2): beers.waitress_id -> waitresses
    2 (out of 2): waitresses.bartender_id -> bartenders
    1 (out of 2): order.beer_id -> beers
    1 (out of 2): bartenders.order_id -> order
    1 (out of 2): bartenders.beer_id -> beers

##### Factories

###### Creating Factories

Autogenerate `test/factories.rb` from all model files in `app/models`:

    bundle exec stepford factories

If you want one file per model, use `--multiple`. The default path is `test/factories`, which it assumes exists. In that directory, it will create a factory file for each model. If you want separate factory files in `spec/factories`, you'd use:

    bundle exec stepford factories --path spec/factories --multiple

###### RSpec

To put all of your factories into `spec/factories.rb`:

    bundle exec stepford factories --path spec

This also works:

    bundle exec stepford factories --path spec/support/factories.rb

###### Specifying Models

By default, Stepford processes all models found in `app/models`.

Specify `--models` and a comma-delimited list of models to only output the models you specify. If you don't want to overwrite existing factory files, you should direct the output to another file and manually copy each in:

    bundle exec stepford factories --path spec/support/put_into_factories.rb --models foo,bar,foo_bar

###### Traits

To generate traits for each attribute that would be included with `--attributes`, but isn't because `--attributes` is not specified:

    bundle exec stepford factories --attribute-traits

To generate traits for each association that would be included with `--associations`, but isn't because `--associations` is not specified:

    bundle exec stepford factories --association-traits

###### Associations

If you use the (cache) wrapper to automatically generate factories, you may not need to generate associations. We had interdependence issues with factories. When there are NOT NULLs on foreign keys and/or presence validations, etc. you can't just use `after(:create)` or `after(:build)` to set associations, and without those you can have issues with "Trait not registered" or "Factory not registered" with interdependent factory associations. 

However, if you don't have anything that complex or don't mind hand-editing the factories to try to fix issues, these might help.

####### Include Required Assocations

To include NOT NULL foreign key associations or presence validated associations:

    bundle exec stepford factories --include-required-associations

####### Include All Associations

To include all associations even if they aren't deemed to be required by not null ActiveRecord constraints defined in the model:

    bundle exec stepford factories --associations

####### Checking Model Associations

If `--associations` or `--validate-associations` is specified, Stepford first loads Rails and attempts to check your models for broken associations.

If associations are deemed broken, it will output proposed changes.

###### No IDs

If working with a legacy schema, you may have models with foreign_key columns that you don't have associations defined for in the model. If that is the case, we don't want to assign arbitrary integers to them and try to create a record. If that is the case, try `--exclude-all-ids`, which will exclude those ids as attributes defined in the factories and you can add associations as needed to get things working.

###### How NOT NULL, and Other Database Constraints and Active Record Validations Are Handled

If the ActiveRecord column `null` property for the attribute is true for the attribute or foreign key for the association, or if there is a presence validator for an attribute or foreign key for the association, then that attribute or association will be defined by the default factory.

Currently uniqueness constraints are ignored and must be handled by FactoryGirl sequence or similar if not automatically populated by your model or the database, e.g. in your factory, if username uniqueness is enforced by a unique constraint on the database-side, you'll need to do something like this manually in the factory:

    sequence(:username) {|n| "user#{n}" }

###### Testing Factories

See [Testing all Factories (with RSpec)][test_factories] in the FactoryGirl wiki.

Here are a few rspecs that test the FactoryGirl factories and the Stepford deep_builds:

    require 'spec_helper'
    require 'stepford/factory_girl_rspec_helpers'

    describe 'validate factories build' do
      FactoryGirl.factories.each do |factory|
        context "with factory for :#{factory.name}" do
          subject { build(factory.name) }

          it "is valid" do
            subject.valid?.should be, subject.errors.full_messages
          end
        end
      end
    end

    describe 'validate factories deep build' do
      FactoryGirl.factories.each do |factory|
        context "with factory for :#{factory.name}" do
          subject { deep_build(factory.name) }

          it "is valid" do
            subject.valid?.should be, subject.errors.full_messages
          end
        end
      end
    end


##### Troubleshooting

If you have duplicate factory definitions during Rails load, it may complain. Just move, rename, or remove the offending files and factories and retry.

The CLI produces factories that use Ruby 1.9 hash syntax. If you aren't using Ruby 1.9, it may not fail during generation, but it might later when loading the factories.

If you are using STI, you'll need to manually fix the value that goes into the `type` attribute, or you can remove those.

Tested with postgreSQL 9.x only.

If you use Stepford to create factories for existing tests and the tests fail with:

     ActiveRecord::StatementInvalid:
       PG::Error: ERROR:  null value in column "something_id" violates not-null constraint

or maybe:

     ActiveRecord::RecordInvalid:
       Validation failed: Item The item is required., Pricer The pricer is required., Purchased by A purchaser is required.

or you might get:

    SystemStackError:
      stack level too deep

ThoughtBot's Josh Clayton provided some suggestions for this, including using methods to generate more complex object structures:

    def post_containing_comment_by_author
      author = FactoryGirl.create(:user)
      post = FactoryGirl.create(:post)
      FactoryGirl.create_list(:comment, 3)
      FactoryGirl.create(:comment, author: author, post: post)
      post.reload
    end

or referring to created objects through associations, though he said multiple nestings get tricky:

    factory :post do
      author
      title 'Ruby is fun'
    end

    factory :comment do
      author
      post
      body 'I love Ruby too!'

      trait :authored_by_post_author do
        author { post.author }
      end
    end

    comment = FactoryGirl.create(:comment, :authored_by_post_author)
    comment.author == comment.post.author # true

This is the reason we wrote the Stepford Factory Girl Wrapper (see above). It automatically determines what needs to be set in what order and does create, create_list or build, build_list, etc. automatically.

### License

Copyright (c) 2012 Gary S. Weaver, released under the [MIT license][lic].

[test_factories]: https://github.com/thoughtbot/factory_girl/wiki/Testing-all-Factories-%28with-RSpec%29
[factory_girl]: https://github.com/thoughtbot/factory_girl/
[lic]: http://github.com/garysweaver/stepford/blob/master/LICENSE
