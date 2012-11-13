require 'factory_girl'
require 'bigdecimal'

module Stepford
  # A proxy for FactoryGirl that automatically recursively creates/builds/stubbed factories for null=false and/or presence validated associations.
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
  module FactoryGirl
    OPTIONS = [
      :debug
    ]

    class << self
      OPTIONS.each{|o|attr_accessor o; define_method("#{o}?".to_sym){!!send("#{o}")}}
      def configure(&blk); class_eval(&blk); end

      def handle_factory_girl_method(m, *args, &block)
        
        if args && args.size > 0
          # call Stepford::FactoryGirl.* on any not null associations recursively
          model_class = args[0].to_s.camelize.constantize

          args = args.dup # need local version because we'll be dup'ing the options hash to add things to set prior to create/build
          options = args.last
          if options.is_a?(Hash)
            # keep them separate
            orig_options = options
            options = deep_dup(options)
            args[(args.size - 1)] = options # need to set the dup'd options
          else
            # keep them separate
            orig_options = {}
            options = {}
            args << options # need to add options to set associations
          end

          options[:with_factory_options] = {} unless options[:with_factory_options]
          with_factory_options = options[:with_factory_options]
          
          orig_options[:nesting_breadcrumbs] = [] unless orig_options[:nesting_breadcrumbs]
          breadcrumbs = orig_options[:nesting_breadcrumbs]
          breadcrumbs << [args[0]]

          orig_options[:to_reload] = [] unless orig_options[:to_reload]
          to_reload = orig_options[:to_reload]
            
          if ::Stepford::FactoryGirl.debug?
            puts "#{breadcrumbs.join('>')} start. args=#{debugargs(args)}"
          end

          model_class.reflections.each do |association_name, reflection|
            assc_sym = reflection.name.to_sym
            next if options[assc_sym] || options[reflection.foreign_key.to_sym] # || reflection.macro != :belongs_to
            
            clas_sym = reflection.class_name.underscore.to_sym
            has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(::ActiveModel::Validations::PresenceValidator)
            required = reflection.foreign_key ? (has_presence_validator || model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym}) : false
            orig_method_args_and_options = with_factory_options ? (with_factory_options[[clas_sym, assc_sym]] || with_factory_options[clas_sym]) : nil
            
            has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(ActiveModel::Validations::PresenceValidator)
            required = false
            if reflection.macro == :belongs_to
              # note: supports composite_primary_keys gem which stores primary_key as an array
              foreign_key_is_also_primary_key = Array.wrap(model_class.primary_key).collect{|pk|pk.to_sym}.include?(reflection.foreign_key.to_sym)
              is_not_null_fkey_that_is_not_primary_key = model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym && !foreign_key_is_also_primary_key}
              required = is_not_null_fkey_that_is_not_primary_key || has_presence_validator
            else
              # no nullable metadata on column if no foreign key in this table. we'd figure out the null requirement on the column if inspecting the child model
              required = has_presence_validator
            end

            if required
              breadcrumbs << ["a:#{assc_sym}"]
              if orig_method_args_and_options
                method_args_and_options = orig_method_args_and_options.dup
                method_options = args.last
                blk = method_options.is_a?(Hash) ? method_args_and_options.delete(:blk) : nil
                begin
                  if blk
                    options[assc_sym] = ::FactoryGirl.__send__(*method_args_and_options, &blk)
                  else
                    options[assc_sym] = ::FactoryGirl.__send__(*method_args_and_options)
                  end
                  to_reload << options[assc_sym]
                rescue ActiveRecord::RecordInvalid => e
                  puts "#{breadcrumbs.join('>')}: FactoryGirl.__send__(#{method_args_and_options.inspect}): #{e}#{::Stepford::FactoryGirl.debug? ? "\n#{e.backtrace.join("\n")}" : ''}"
                  raise e
                end
              else
                if reflection.macro == :has_many
                  options[assc_sym] = ::Stepford::FactoryGirl.create_list(clas_sym, 2, orig_options)               
                else
                  options[assc_sym] = ::Stepford::FactoryGirl.create(clas_sym, orig_options)
                end
              end
              breadcrumbs.pop
            end
          end
        end

        if defined?(breadcrumbs)
          if ::Stepford::FactoryGirl.debug?
            puts "#{breadcrumbs.join('>')} end"
            puts "#{breadcrumbs.join('>')} FactoryGirl.#{m}(#{debugargs(args)})"
          end
          breadcrumbs.pop
        end

        # clean-up before sending to FactoryGirl
        if args.last.is_a?(Hash)
          (args.last).delete(:with_factory_options)
          (args.last).delete(:nesting_breadcrumbs)
          (args.last).delete(:to_reload)
        end

        begin
          result = ::FactoryGirl.__send__(m, *args, &block)
        rescue ActiveRecord::RecordInvalid => e
          puts "#{breadcrumbs.join('>')}: FactoryGirl.#{m}(#{args.inspect}): #{e}#{::Stepford::FactoryGirl.debug? ? "\n#{e.backtrace.join("\n")}" : ''}" if defined?(breadcrumbs)
          raise e
        end
        
        if args.last.is_a?(Hash) && defined?(breadcrumbs) && breadcrumbs.size > 0
          # still handling association/subassociation
          args.last[:nesting_breadcrumbs] = breadcrumbs
          args.last[:to_reload] = to_reload
          orig_options[:to_reload] << result
        else
          # ready to return the initially requested instances, so reload children with their parents, in reverse order added
          orig_options[:to_reload].reverse.each do |i|
            begin
              i.reload
            rescue => e
              puts "#{i} reload failed: #{e}\n#{e.backtrace.join("\n")}" if ::Stepford::FactoryGirl.debug?
            end
          end
        end

        result
      end

      # switched to this from method_missing to avoid method trying to handle mistaken calls
      def create(*args, &block); handle_factory_girl_method(:create, *args, &block); end
      def create_list(*args, &block); handle_factory_girl_method(:create_list, *args, &block); end
      def build(*args, &block); handle_factory_girl_method(:build, *args, &block); end
      def build_list(*args, &block); handle_factory_girl_method(:build_list, *args, &block); end
      def build_stubbed(*args, &block); handle_factory_girl_method(:build_stubbed, *args, &block); end
      # pass everything else to FactoryGirl to try to handle (can't reflect in current version to find what it handles)
      def method_missing(m, *args, &block); ::FactoryGirl.__send__(m, *args, &block); end

      def deep_dup(o)
        result = nil
        if o.is_a?(Hash)
          result = {}
          o.keys.each do |key|
            result[deep_dup(key)] = deep_dup(o[key])
          end
        elsif o.is_a?(Array)
          result = []
          o.each do |value|
            result << deep_dup(value)
          end
        elsif [NilClass,FalseClass,TrueClass,Symbol,Numeric,Class,Module].any?{|c|o.is_a?(c)}
          result = o
        elsif o.is_a?(BigDecimal)
          # ActiveSupport v3.2.8 checks duplicable? for BigDecimal by testing it, so we'll just try to dup the value itself
          result = o
          begin
            result = o.dup
          rescue TypeError
            # can't dup
          end
        elsif o.is_a?(Object)
          result = o.dup
        else
          result = o
        end
        result
      end

      def debugargs(args)
        result = []
        args.each do |arg|
          if arg.is_a?(Hash)
            result << "{#{arg.keys.collect{|key|"#{key} = (#{arg[key].class.name})"}.join(', ')}}"
          else
            result << "#{arg.inspect},"
          end
        end
        result.join('')
      end
    end
  end
end
