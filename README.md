Stepford
=====

Stepford is a CLI to create starter [Factory Girl][factory_girl] factories for all of your Rails models, e.g.

    require 'factory_girl_rails'

    FactoryGirl.define do
    
      factory :post do
        author
        association :edited_by, factory: :user
        FactoryGirl.create_list :comments, 2
        created_at { 2.weeks.ago }
        name 'Test Name'
        price 1.23
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

The default will assume a `test/factories` directory exists. In that directory, it will create a factory file for each model containing example values for all attributes except primary keys, foreign keys, created_at, and updated_at:

    bundle exec stepford factories

To put all of your factories into `spec/factories.rb`:

    bundle exec stepford factories --single --path spec

It will figure out that you want a single file, if the path ends in `.rb`:

    bundle exec stepford factories --path spec/support/factories.rb

### Associations

To include associations:

    bundle exec stepford factories --associations

### Stepford Checks Model Associations

If `--associations` or `--validate-associations` is specified, Stepford first loads Rails and attempts to check your models for broken associations.

If associations are deemed broken, it will output proposed changes.

### No IDs

If working with a legacy schema, you may have models with foreign_key columns that you don't have associations defined for in the model. If that is the case, we don't want to assign arbitrary integers to them and try to create a record. If that is the case, try `--exclude-all-ids`, which will exclude those ids as attributes defined in the factories and you can add associations as needed to get things working.

### Specifying Models

Specify `--models` and a comma-delimited list of models to only output the models you specify. If you don't want to overwrite existing factory files, you should direct the output to another file and manually copy each in:

    bundle exec stepford factories --path spec/support/put_into_factories.rb --models foo,bar,foo_bar

### Troubleshooting

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

If you specify `--associations`, you might get circular associations and could easily end up with:

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

### License

Copyright (c) 2012 Gary S. Weaver, released under the [MIT license][lic].

[factory_girl]: https://github.com/thoughtbot/factory_girl/
[lic]: http://github.com/garysweaver/stepford/blob/master/LICENSE
