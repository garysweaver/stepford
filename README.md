Stepford
=====

Stepford is a CLI to create starter [Factory Girl][factory_girl] factories for all of your Rails models, e.g.

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

#### Factory Girl

##### How NOT NULL, and Other Database Constraints and Active Record Validations Are Handled

If the ActiveRecord column `null` property for the attribute is true for the attribute or foreign key for the association, or if there is a presence validator for an attribute or foreign key for the association, then that attribute or association will be defined by the default factory.

Currently uniqueness constraints are ignored and must be handled by FactoryGirl sequence or similar if not automatically populated by your model or the database, e.g. in your factory, if username uniqueness is enforced by a unique constraint on the database-side, you'll need to do something like this manually in the factory:

    sequence(:username) {|n| "user#{n}" }

##### Creating Factories

The default will assume a `test/factories` directory exists. In that directory, it will create a factory file for each model containing example values for all attributes except primary keys, foreign keys, created_at, and updated_at:

    bundle exec stepford factories

To put all of your factories into `spec/factories.rb`:

    bundle exec stepford factories --single --path spec

It will figure out that you want a single file, if the path ends in `.rb`:

    bundle exec stepford factories --path spec/support/factories.rb

##### Traits

To generate traits for each attribute that would be included with `--attributes`, but isn't because `--attributes` is not specified:

    bundle exec stepford factories --attribute-traits

To generate traits for each association that would be included with `--associations`, but isn't because `--associations` is not specified:

    bundle exec stepford factories --association-traits

##### Associations

To include all associations even if they aren't deemed to be required by not null ActiveRecord constraints defined in the model:

    bundle exec stepford factories --associations

##### Stepford Checks Model Associations

If `--associations` or `--validate-associations` is specified, Stepford first loads Rails and attempts to check your models for broken associations.

If associations are deemed broken, it will output proposed changes.

##### No IDs

If working with a legacy schema, you may have models with foreign_key columns that you don't have associations defined for in the model. If that is the case, we don't want to assign arbitrary integers to them and try to create a record. If that is the case, try `--exclude-all-ids`, which will exclude those ids as attributes defined in the factories and you can add associations as needed to get things working.

##### Singleton Values

Use `--cache-associations` to store and use factories to avoid 'stack level too deep' errors.

##### Specifying Models

Specify `--models` and a comma-delimited list of models to only output the models you specify. If you don't want to overwrite existing factory files, you should direct the output to another file and manually copy each in:

    bundle exec stepford factories --path spec/support/put_into_factories.rb --models foo,bar,foo_bar

##### Testing Factories

See [Testing all Factories (with RSpec)][test_factories] in the FG wiki.

##### Troubleshooting

If you have duplicate factory definitions during Rails load, it may complain. Just move, rename, or remove the offending files and factories and retry.

Stepford produces factories that use Ruby 1.9 hash syntax. If you aren't using Ruby 1.9, it may not fail during generation, but it might later when loading the factories.

If you are using STI, you'll need to manually fix the value that goes into the `type` attribute, or you can remove those.

Tested with postgreSQL 9.x only.

If you use Stepford to create factories for existing tests and the tests fail with:

     ActiveRecord::StatementInvalid:
       PG::Error: ERROR:  null value in column "something_id" violates not-null constraint

or maybe:

     ActiveRecord::RecordInvalid:
       Validation failed: Item The item is required., Pricer The pricer is required., Purchased by A purchaser is required.

you might either need to modify those factories to set associations that are required or specify `--associations` in Stepford to attempt generate them.

Without `--cache-associations`, you might get circular associations and could easily end up with:

    SystemStackError:
      stack level too deep

ThoughtBot's Josh Clayton also provided some suggestions for this, including using methods to generate more complex object structures:

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

### License

Copyright (c) 2012 Gary S. Weaver, released under the [MIT license][lic].

[singletons]: http://stackoverflow.com/questions/2015473/using-factory-girl-in-rails-with-associations-that-have-unique-constraints-gett/3569062#3569062
[test_factories]: https://github.com/thoughtbot/factory_girl/wiki/Testing-all-Factories-%28with-RSpec%29
[factory_girl]: https://github.com/thoughtbot/factory_girl/
[lic]: http://github.com/garysweaver/stepford/blob/master/LICENSE
