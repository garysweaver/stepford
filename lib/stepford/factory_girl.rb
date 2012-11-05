require 'stepford/common'

module Stepford
  class FactoryGirl
    CACHE_VALUES_FILENAME = 'fg_cache.rb'

    def self.generate_factories(options={})
      # guard against circular references
      if options[:cache_associations]
        File.open(File.join(File.dirname(get_factories_rb_pathname(options)), CACHE_VALUES_FILENAME), "w") do |f|
          #TODO: just copy this file from the gem to project vs. writing it like this
          f.puts '# originally created by Stepford: https://github.com/garysweaver/stepford'
          f.puts '# idea somewhat based on d2vid and snowangel\'s answer in http://stackoverflow.com/questions/2015473/using-factory-girl-in-rails-with-associations-that-have-unique-constraints-gett/3569062#3569062'
          f.puts 'fg_cachehash = {}'
          f.puts 'def fg_cache(class_sym, assc_sym = nil, number = nil)'
          # if missing 3rd arg, assume 2nd arg is 3rd arg or use default
          # if missing 2nd and 3rd arg, assume 2nd arg is 1st arg
          f.puts '  number ||= assc_sym'
          f.puts '  assc_sym ||= class_sym'
          f.puts '  fg_cachehash[factory_sym, assc_sym, number] ||= (number ? FactoryGirl.create_list(class_sym, number) : FactoryGirl.create(class_sym))'
          f.puts 'end'
        end
      end

      factories = {}
      expected = {}
      included_models = options[:models] ? options[:models].split(',').collect{|s|s.strip}.compact : nil
      Dir[File.join('app','models','*.rb').to_s].each do |filename|
        model_name = File.basename(filename).sub(/.rb$/, '')
        next if included_models && !included_models.include?(model_name)
        load File.join('app','models',"#{model_name}.rb")
        model_class = model_name.camelize.constantize
        next unless model_class.ancestors.include?(ActiveRecord::Base)
        factory = (factories[model_name.to_sym] ||= [])
        excluded_attributes = Array.wrap(model_class.primary_key).collect{|pk|pk.to_sym} + [:updated_at, :created_at]
        association_lines = model_class.reflections.collect {|association_name, reflection|
          (expected[reflection.class_name.underscore.to_sym] ||= []) << model_name
          excluded_attributes << reflection.foreign_key.to_sym if reflection.foreign_key
          assc_sym = reflection.name.to_sym
          clas_sym = reflection.class_name.underscore.to_sym
          # if has a foreign key, then if NOT NULL or is a presence validate, the association is required and should be output. unfortunately this could mean a circular reference that will have to be manually fixed
          has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(ActiveModel::Validations::PresenceValidator)
          required = reflection.foreign_key ? (has_presence_validator || model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym}) : false
          should_be_trait = !(options[:associations] || required) && options[:association_traits]
          if options[:associations] || required || should_be_trait
            if options[:cache_associations]
              if reflection.macro == :has_many              
                "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}after(:create) do |user, evaluator|; #{is_reserved?(assc_sym) ? 'self.' : ''}#{assc_sym} = fg_cache(#{clas_sym.inspect}#{clas_sym == assc_sym ? '' : ", #{assc_sym.inspect}"}, 2); end"
              else
                "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}after(:create) do |user, evaluator|; #{is_reserved?(assc_sym) ? 'self.' : ''}#{assc_sym} = fg_cache(#{clas_sym.inspect}#{clas_sym == assc_sym ? '' : ", #{assc_sym.inspect}"}); end"
              end
            else
              if reflection.macro == :has_many              
                "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}#{should_be_trait || has_presence_validator ? '' : '#'}after(:create) do |user, evaluator|; FactoryGirl.create_list #{clas_sym.inspect}, 2; end#{should_be_trait ? '; end' : ''}#{should_be_trait ? '' : ' # commented to avoid circular reference'}"
              elsif assc_sym != clas_sym
                "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}#{should_be_trait || reflection.macro == :belongs_to || has_presence_validator ? '' : '#'}association #{assc_sym.inspect}#{assc_sym != clas_sym ? ", factory: #{clas_sym.inspect}" : ''}#{should_be_trait ? '; end' : ''}#{should_be_trait || reflection.macro == :belongs_to ? '' : ' # commented to avoid circular reference'}"
              else
                "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}#{should_be_trait || reflection.macro == :belongs_to || has_presence_validator ? '' : '#'}#{is_reserved?(assc_sym) ? 'self.' : ''}#{assc_sym}#{should_be_trait ? '; end' : ''}#{should_be_trait || reflection.macro == :belongs_to ? '' : ' # commented to avoid circular reference'}"
              end
            end
          else
            nil
          end
        }.compact.sort.each {|l|factory << l}
        model_class.columns.sort_by {|c|[c.name]}.each {|c|
          if !excluded_attributes.include?(c.name.to_sym) && !(c.name.downcase.end_with?('_id') && options[:exclude_all_ids]) && (options[:attributes] || !c.null)
            factory << "#{c.name} #{Stepford::Common.value_for(c)}"
          elsif options[:attribute_traits]
            if c.type == :boolean
              factory << "trait #{c.name.underscore.to_sym.inspect} do; #{c.name} true; end"
              factory << "trait #{"not_#{c.name.underscore}".to_sym.inspect} do; #{c.name} false; end"
            else
              factory << "trait #{"with_#{c.name.underscore}".to_sym.inspect} do; #{c.name} #{Stepford::Common.value_for(c)}; end"
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
      # from http://stackoverflow.com/questions/6461303/built-in-way-to-determine-whether-a-string-is-a-ruby-reserved-word/6461673#6461673
      %w{__FILE__ __LINE__ alias and begin BEGIN break case class def defined? do else elsif end END ensure false for if in module next nil not or redo rescue retry return self super then true undef unless until when while yield}.include? s.to_s
    end

    def self.get_factories_rb_pathname(options)
      path = File.join('test','factories.rb')
      if options[:path]
        if options[:path].end_with?('.rb')
          path = options[:path]
        else
          if options[:single]
            path = File.join(options[:path],'factories.rb')
          else
            path = options[:path]
          end
        end
      end
      path
    end

    def self.write_header(f, options)
      f.puts 'require \'factory_girl_rails\''
      f.puts "require_relative \'#{CACHE_VALUES_FILENAME.chomp('.rb')}\'" if options[:cache_associations]
      f.puts ''
      f.puts '# originally created by Stepford: https://github.com/garysweaver/stepford'
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
