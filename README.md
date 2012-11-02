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

The default will assume a `test/factories` directory exists and that it should create a factory file for each model with non-primary key, non-foreign key attributes only, and no associations:

    bundle exec stepford factories

To put all of your factories into `spec/factories.rb`:

    bundle exec stepford factories --single --path spec

It will figure out that you want a single file, if the path ends in `.rb`:

    bundle exec stepford factories --path spec/support/factories.rb

### Associations

To include associations:

    bundle exec stepford factories --associations

### Stepford Checks Model Associations

If `--associations` or `--validate_associations` is specified, Stepford first loads Rails and attempts to check your models for broken associations.

If associations are deemed broken, it will output proposed changes.

### Troubleshooting

If you have duplicate factory definitions during Rails load, it may complain. Just move, rename, or remove the offending files and factories and retry.

Uses the Ruby 1.9 hash syntax in generated factories. If you don't have 1.9, it might not fail during generation, but it may later when loading the factories.

If you are using STI, you'll need to manually fix the value that goes into the `type` attribute, or remove it.

If you specify `--associations`, you might run into issue with circular associations, so you could easily end up with:

    SystemStackError:
      stack level too deep

Some suggestions from ThoughtBot's Josh Clayton provided include using methods to generate more complex object structures:

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
