require 'factory_girl'

module Stepford
  # A wrapper for FactoryGirl that automatically recursively creates/builds/stubbed factories for null=false and/or presence validated associations.
  #
  # Lets you specify method name and arguments/options to factory girl for associations.
  #
  # e.g. if the following is required:
  # * Bar has a required association called house_special which uses the :beer factory, and we have a block we want to send into it
  # * Beer has specials that you want to build as a list of 3 using the :tuesday_special_offer factory
  # then you could set that up like this:
  #   Stepford::FactoryGirl.create_list(:bar, with_factory_options: {
  #     house_special: [:create, :beer, {blk: ->(beer) do; beer.bubbles.create(attributes_for(:bubbles)); end}],
  #     specials: [:build_list, :tuesday_special_offer, 3]
  #   }) do
  #     # the block you would send to FactoryGirl.create_list(:foo) would go here
  #   end
  #
  # If you have a circular reference (A has NOT NULL foreign key to B that has NOT NULL foreign key to C that has NOT NULL foreign key to A) in the
  # schema, there is a workaround. First, prepopulate one of the models involved in the interdependency chain in the database as part of test setup,
  # or if the ids are NOT NULL but are not foreign key constrained (i.e. if you can enter an invalid ID into the foreign key column, which implies possible 
  # referential integrity issues) then you may be able to set them with an invalid id. Take that foreign id and then use the following to ensure
  # that it will set that foreign id or instance. This is done at a global level which may not work for you, but it makes it convenient to put into
  # your spec/spec_helper.rb, etc. For example, let's say your bar has NOT NULL on bartender_id and waiter_id, and in turn bartender and waiter
  # both have a NOT NULL bar_id, and neither enforce foreign keys. Maybe you have preloaded data for waiter somehow as the id '123', but want to set bartender to
  # just use an invalid id '-1', and you want to do it when they are on their second loop. You could use:
  #
  #   Stepford::FactoryGirl.stop_circular_refs = {
  #      [:bartender, :bar] => {on_loop: 2, set_foreign_key_to: -1},
  #      [:waiter, :bar] => {on_loop: 2, set_to: Waiter.find(123)},
  #   }
  module FactoryGirl
    OPTIONS = [
      :debug,
      :stop_circular_refs
    ]

    class << self
      OPTIONS.each{|o|attr_accessor o; define_method("#{o}?".to_sym){!!send("#{o}")}}
      def configure(&blk); class_eval(&blk); end

      def method_missing(m, *args, &block)
        puts "handling Stepford::FactoryGirl.#{m}(#{args.inspect})" if ::Stepford::FactoryGirl.debug?

        if [:build, :build_list, :build_stubbed, :create, :create_list].include?(m) && args && args.size > 0
          # call Stepford::FactoryGirl.* on any not null associations recursively
          model_sym = args[0].to_sym
          model_class = args[0].to_s.camelize.constantize

          args = args.dup # need local version because we'll be dup'ing the options hash to add things to set prior to create/build
          options = args.last
          if options.is_a?(Hash)
            options = options.dup
            args[(args.size - 1)] = options # need to set the dup'd options
          else
            options = {}
            args << options # need to add options to set associations
          end

          options[:with_factory_options] = {} unless options[:with_factory_options]
          with_factory_options = options[:with_factory_options]
          with_factory_options[:circular_ref_counts] = {} unless with_factory_options[:circular_ref_counts]
          model_class.reflections.each do |association_name, reflection|
            assc_sym = reflection.name.to_sym
            next if options[assc_sym] || options[reflection.foreign_key.to_sym]
            clas_sym = reflection.class_name.underscore.to_sym
            has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(::ActiveModel::Validations::PresenceValidator)
            required = reflection.foreign_key ? (has_presence_validator || model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym}) : false
            orig_method_args_and_options = with_factory_options ? (with_factory_options[[clas_sym, assc_sym]] || with_factory_options[clas_sym]) : nil
            # if has a foreign key, then if NOT NULL or is a presence validate, the association is required and should be output. unfortunately this could mean a circular reference that will have to be manually fixed
            has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(ActiveModel::Validations::PresenceValidator)
            # note: supports composite_primary_keys gem which stores primary_key as an array
            foreign_key_is_also_primary_key = Array.wrap(model_class.primary_key).collect{|pk|pk.to_sym}.include?(reflection.foreign_key.to_sym)
            is_not_null_fkey_that_is_not_primary_key = model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym && !foreign_key_is_also_primary_key}

            if is_not_null_fkey_that_is_not_primary_key || has_presence_validator
              circular_ref_key = [model_sym, assc_sym]
              all_opts = ::Stepford::FactoryGirl.stop_circular_refs
              if all_opts.is_a?(Hash) && all_opts.size > 0
                circ_options = all_opts[circular_ref_key]
                if circ_options
                  #puts "::Stepford::FactoryGirl.stop_circular_refs[circular_ref_key]=#{circ_options.inspect}"
                  count = with_factory_options[:circular_ref_counts][circular_ref_key]
                  if count
                    count += 1
                  else
                    count = 0
                  end
                  with_factory_options[:circular_ref_counts][circular_ref_key] = count
                  if count > 100
                    puts "over 100 loops. run: bundle exec stepford circular to find circular dependencies, then either change related NOT NULL columns to nullable and/or remove presence validators for related associations, or use Stepford::FactoryGirl.stop_circular_refs, e.g. #{circular_ref_key.inspect} => {on_loop: 2, set_foreign_key_to: -1}" if ::Stepford::FactoryGirl.debug?
                  end

                  if count >= (circ_options[:on_loop] || 1)
                    if circ_options.has_key?(:set_to)
                      puts "Circular dependency override enabled. Returning :set_to instance to set as #{model_sym}.#{assc_sym}. instance was #{circ_options[:set_to]}" if ::Stepford::FactoryGirl.debug?
                      return circ_options[:set_to]
                    elsif circ_options.has_key?(:set_foreign_key_to)
                      # (CHILD) return hash to set on parent
                      puts "Circular dependency override enabled. Returning :set_foreign_key_to to set as #{model_sym}.#{reflection.foreign_key}. value was '#{circ_options[:set_foreign_key_to]}'" if ::Stepford::FactoryGirl.debug?
                      return {reflection.foreign_key.to_sym => circ_options[:set_foreign_key_to]}
                    end
                  end
                end
              end

              if orig_method_args_and_options
                method_args_and_options = orig_method_args_and_options.dup
                method_options = args.last
                blk = method_options.is_a?(Hash) ? method_args_and_options.delete(:blk) : nil
                if blk
                  puts "FactoryGirl.__send__(#{method_args_and_options.inspect}, &blk)" if ::Stepford::FactoryGirl.debug?
                  options[assc_sym] = ::FactoryGirl.__send__(*method_args_and_options, &blk)
                else
                  puts "FactoryGirl.__send__(#{method_args_and_options.inspect})" if ::Stepford::FactoryGirl.debug?
                  options[assc_sym] = ::FactoryGirl.__send__(*method_args_and_options)
                end
              else
                if reflection.macro == :has_many
                  case m
                  when :create, :create_list
                    options[assc_sym] = ::Stepford::FactoryGirl.create_list(clas_sym, 2, options)
                  when :build, :build_list
                    options[assc_sym] = ::Stepford::FactoryGirl.build_list(clas_sym, 2, options)
                  when :build_stubbed
                    #TODO: need to test building something stubbed that has a PresenceValidator on a has_many
                    options[assc_sym] = ::Stepford::FactoryGirl.build_stubbed(clas_sym, options)
                  end                
                else
                  case m
                  when :create, :create_list
                    options[assc_sym] = ::Stepford::FactoryGirl.create(clas_sym, options)
                  when :build, :build_list
                    options[assc_sym] = ::Stepford::FactoryGirl.build(clas_sym, options)
                  when :build_stubbed
                    options[assc_sym] = ::Stepford::FactoryGirl.build_stubbed(clas_sym, options)
                  end

                  # (PARENT) we passed this back as a hash which means that the child model needed to set foreign key on the parent model
                  if options[assc_sym].is_a?(Hash)
                    value = options.delete(assc_sym)
                    options.merge!(value)
                    puts "Overrode foreign key #{model_sym}.#{assc_sym} = #{value}" if ::Stepford::FactoryGirl.debug?
                  end
                end
              end
            end
          end
        end

        # clean-up before sending to FactoryGirl
        (args.last).delete(:with_factory_options) if args.last.is_a?(Hash)

        puts "FactoryGirl.#{m}(#{args.inspect}) (via __send__)" if ::Stepford::FactoryGirl.debug?
        ::FactoryGirl.__send__(m, *args, &block)
      end
    end
  end
end
