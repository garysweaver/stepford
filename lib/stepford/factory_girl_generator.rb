require 'stepford/common'

module Stepford
  class FactoryGirlGenerator
    def self.generate_factories(options={})
      factories = {}
      expected = {}
      included_models = options[:models] ? options[:models].split(',').collect{|s|s.strip}.compact : nil
      Dir[File.join('app','models','*.rb').to_s].each do |filename|
        model_name = File.basename(filename).sub(/.rb$/, '')
        next if included_models && !included_models.include?(model_name)
        load File.join('app','models',"#{model_name}.rb")
        
        begin
          model_class = model_name.camelize.constantize
        rescue => e
          puts "Problem in #{model_name.camelize}"
          raise e
        end

        next unless model_class.ancestors.include?(ActiveRecord::Base)
        factory = (factories[model_name.to_sym] ||= [])
        pk_syms = Array.wrap(model_class.primary_key).collect{|pk|pk.to_sym}
        excluded_attributes = pk_syms + [:updated_at, :created_at, :object_id]
        model_class.reflections.collect {|association_name, reflection|
          (expected[reflection.class_name.underscore.to_sym] ||= []) << model_name
          fkey_sym = reflection.foreign_key.try(:to_sym)
          excluded_attributes << fkey_sym if reflection.foreign_key && !(excluded_attributes.include?(fkey_sym))
          assc_sym = reflection.name.to_sym
          clas_sym = reflection.class_name.underscore.to_sym
          # if has a foreign key, then if NOT NULL or is a presence validate, the association is required and should be output. unfortunately this could mean a circular reference that will have to be manually fixed          
          has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(ActiveModel::Validations::PresenceValidator)
          required = reflection.foreign_key ? (has_presence_validator || model_class.columns.any?{|c| !c.null && c.name.to_sym == fkey_sym}) : false
          should_be_trait = !(options[:associations] || (options[:include_required_associations] && required)) && options[:association_traits]
          if options[:associations] || (options[:include_required_associations] && required) || should_be_trait
            if reflection.macro == :has_many
              # In factory girl v4.1.0:
              # create_list must be done in an after(:create) or you get Trait not registered or Factory not registered errors.
              # this means that validators that verify presence or size > 0 in a association list will not work with this method, and you'll need to
              # use build, not create: http://stackoverflow.com/questions/11209347/has-many-with-at-least-two-entries
              "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}#{should_be_trait || has_presence_validator ? '' : '#'}after(:create) do |user, evaluator|; FactoryGirl.create_list #{clas_sym.inspect}, 2; end#{should_be_trait ? '; end' : ''}#{should_be_trait ? '' : ' # commented to avoid circular reference'}"
            elsif assc_sym != clas_sym
              "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}#{should_be_trait || reflection.macro == :belongs_to || has_presence_validator ? '' : '#'}association #{assc_sym.inspect}#{assc_sym != clas_sym ? ", factory: #{clas_sym.inspect}" : ''}#{should_be_trait ? '; end' : ''}#{should_be_trait || reflection.macro == :belongs_to ? '' : ' # commented to avoid circular reference'}"
            else
              "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}#{should_be_trait || reflection.macro == :belongs_to || has_presence_validator ? '' : '#'}#{is_reserved?(assc_sym) ? 'self.' : ''}#{assc_sym}#{should_be_trait ? '; end' : ''}#{should_be_trait || reflection.macro == :belongs_to ? '' : ' # commented to avoid circular reference'}"
            end
          else
            nil
          end
        }.compact.sort.each {|l|factory << l}

        sequenceless_table = false
        begin
          sequenceless_table = true unless m.sequence_name
        rescue => e
          # bug in Rails 3.2.8, at least: undefined method `split' for nil:NilClass in activerecord-3.2.8/lib/active_record/connection_adapters/postgresql_adapter.rb:911:in `default_sequence_name'
          sequenceless_table = true
        end

        model_class.columns.sort_by {|c|[c.name]}.each {|c|
          # intentional not checking excluded_attributes/exclude_all_ids when sequenceless. it needs these for create to work.
          if sequenceless_table && pk_syms.include?(c.name.to_sym)
            factory << Stepford::Common.sequence_for(c)
          elsif !excluded_attributes.include?(c.name.to_sym) && !(c.name.to_s.downcase.end_with?('_id') && options[:exclude_all_ids]) && (options[:attributes] || !c.null)
            has_uniqueness_validator = model_class.validators_on(c.name.to_sym).collect{|v|v.class}.include?(ActiveRecord::Validations::UniquenessValidator)
            if has_uniqueness_validator
              #TODO: specialize for different data types
              factory << Stepford::Common.sequence_for(c)
            else
              factory << "#{is_reserved?(c.name) ? 'self.' : ''}#{c.name} #{Stepford::Common.value_for(c)}"
            end
          elsif options[:attribute_traits]
            if c.type == :boolean
              factory << "trait #{c.name.underscore.to_sym.inspect} do; #{is_reserved?(c.name) ? 'self.' : ''}#{c.name} true; end"
              factory << "trait #{"not_#{c.name.underscore}".to_sym.inspect} do; #{is_reserved?(c.name) ? 'self.' : ''}#{c.name} false; end"
            else
              factory << "trait #{"with_#{c.name.underscore}".to_sym.inspect} do; #{is_reserved?(c.name) ? 'self.' : ''}#{c.name} #{Stepford::Common.value_for(c)}; end"
            end
          end
        }
      end

      if options[:associations] || options[:validate_associations]
        failed = false
        model_to_fixes_required = {}
        expected.keys.sort.each do |factory_name|
          unless factories[factory_name.to_sym]
            puts "#{File.join('app','models',"#{factory_name}.rb")} missing. Model(s) with associations to it: #{expected[factory_name].sort.join(', ')}"
            expected[factory_name].each do |model_name|
              (model_to_fixes_required[model_name.to_sym] ||= []) << factory_name.to_sym
            end
            failed = true
          end
        end
        model_to_fixes_required.keys.each do |model_to_fix|
          puts ""
          puts "In #{model_to_fix}:"
          model_to_fixes_required[model_to_fix].each do |fix|
            puts "- comment/remove/fix broken association to #{fix}"
          end
        end
        return false if failed
      end

      path = get_factories_rb_pathname(options)
      
      if path.end_with?('.rb')
        dirpath = File.dirname(path)
        unless File.directory?(dirpath)
          puts "Please create this directory first: #{dirpath}"
          return false
        end

        File.open(path, "w") do |f|
          write_header(f, options)           
          factories.keys.sort.each do |factory_name|
            factory = factories[factory_name]
            write_factory(factory_name, factory, f)
          end
          write_footer(f)
        end
      else
        unless File.directory?(path)
          puts "Please create this directory first: #{path}"
          return false
        end

        factories.keys.sort.each do |factory_name|
          factory = factories[factory_name]
          File.open(File.join(path,"#{factory_name}.rb"), "w") do |f|
            write_header(f, options)
            write_factory(factory_name, factory, f)
            write_footer(f)
          end
        end
      end

      return true
    end

    private

    def self.is_reserved?(s)
      # modified from http://stackoverflow.com/questions/6461303/built-in-way-to-determine-whether-a-string-is-a-ruby-reserved-word/6461673#6461673
      %w{__FILE__ __LINE__ alias and begin BEGIN break case class def defined? do else elsif end END ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield}.include? s.to_s
    end

    def self.get_factories_rb_pathname(options)
      path = File.join('test','factories.rb')
      if options[:path]
        if options[:path].end_with?('.rb')
          path = options[:path]
        else
          if options[:multiple]
            path = options[:path]
          else
            path = File.join(options[:path],'factories.rb')
          end
        end
      end
      path
    end

    def self.write_header(f, options)
      f.puts '# original version autogenerated by Stepford: https://github.com/garysweaver/stepford'
      f.puts ''
      f.puts 'FactoryGirl.define do'
      f.puts '  '
    end
    
    def self.write_factory(factory_name, factory, f)
      f.puts "  factory #{factory_name.inspect} do"
      factory.each do |line|
        f.puts "    #{line}"
      end
      f.puts '  end'
      f.puts '  '
    end

    def self.write_footer(f)
      f.puts 'end'
    end
  end
end
