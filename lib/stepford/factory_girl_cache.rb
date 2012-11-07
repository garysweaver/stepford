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
  module FactoryGirlCache
    class << self
      def method_missing(m, *args, &block)
        puts "Stepford::FactoryGirlCache.#{m}(#{args.inspect})"
        stepford_command_options = {}
        args = args.dup # need local version because we'll be dup'ing the options hash to add things to set prior to create/build
        options = args.last
        if options.is_a?(Hash)
          options = options.dup
          args[(args.size - 1)] = options # need to set the dup'd options
          with_factory_options = options.delete(:with_factory_options)
          stepford_command_options = (with_factory_options ? {with_factory_options: with_factory_options} : {})
        else
          options = {}
          args << options # need to add options to set associations
        end

        if [:build, :build_list, :build_stubbed, :create, :create_list].include?(m) && args && args.size > 0
          # key in the with_factory_options is association class symbol OR [association class symbol, association name symbol]
          # value is *args (array and possible hash)
          key_to_method_args_and_options = stepford_command_options[:with_factory_options]

          # call Stepford::FactoryGirlCache.* on any not null associations recursively, and create an options hash with those as values, if not already passed in
          model_class = args[0].to_s.camelize.constantize
          model_class.reflections.each do |association_name, reflection|
            assc_sym = reflection.name.to_sym
            next if options[assc_sym]            
            clas_sym = reflection.class_name.underscore.to_sym
            has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(::ActiveModel::Validations::PresenceValidator)
            required = reflection.foreign_key ? (has_presence_validator || model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym}) : false
            orig_method_args_and_options = key_to_method_args_and_options ? (key_to_method_args_and_options[[clas_sym, assc_sym]] || key_to_method_args_and_options[clas_sym]) : nil
            if required || orig_method_args_and_options
              if orig_method_args_and_options
                method_args_and_options = orig_method_args_and_options.dup
                method_options = args.last
                blk = method_options.is_a?(Hash) ? method_args_and_options.delete(:blk) : nil
                if blk
                  puts "FactoryGirlCache.__send__(#{method_args_and_options.inspect}, &blk)"
                  options[assc_sym] = ::FactoryGirlCache.__send__(*method_args_and_options, &blk)
                else
                  puts "FactoryGirlCache.__send__(#{method_args_and_options.inspect})"
                  options[assc_sym] = ::FactoryGirlCache.__send__(*method_args_and_options)
                end
              else
                if reflection.macro == :has_many
                  case m
                  when :create, :create_list
                    options[assc_sym] = ::Stepford::FactoryGirlCache.create_list(*[clas_sym, 2, stepford_command_options])
                  when :build, :build_list
                    options[assc_sym] = ::Stepford::FactoryGirlCache.build_list(*[clas_sym, 2, stepford_command_options])
                  when :build_stubbed
                    #TODO: need to test building something stubbed that has a PresenceValidator on a has_many
                    options[assc_sym] = ::Stepford::FactoryGirlCache.build_stubbed(*[clas_sym, stepford_command_options])
                  end                
                else
                  case m
                  when :create, :create_list
                    options[assc_sym] = ::Stepford::FactoryGirlCache.create(*[clas_sym, stepford_command_options])
                  when :build, :build_list
                    options[assc_sym] = ::Stepford::FactoryGirlCache.build(*[clas_sym, stepford_command_options])
                  when :build_stubbed
                    options[assc_sym] = ::Stepford::FactoryGirlCache.build_stubbed(*[clas_sym, stepford_command_options])
                  end
                end
              end
            end
          end
        end
        
        puts "FactoryGirlCache.__send__(#{([m] + Array.wrap(args)).inspect}, &block)"
        ::FactoryGirlCache.__send__(m, *args, &block)
      end
    end
  end
end
