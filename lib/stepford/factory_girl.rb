require 'stepford/common'

module Stepford
  class FactoryGirl
    def self.generate_factories(options={})
      # guard against circular references
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
          required = reflection.foreign_key ? (model_class.validators_on(assc_sym).collect{|v|v.class}.include?(ActiveModel::Validations::PresenceValidator) || model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym}) : false
          should_be_trait = !(options[:associations] || required) && options[:association_traits]
          if options[:associations] || required || should_be_trait
            if reflection.macro == :has_many
              "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}#{should_be_trait ? '' : '#'}FactoryGirl.create_list #{clas_sym.inspect}, 2#{should_be_trait ? '; end' : ''}#{should_be_trait ? '' : ' # commented to avoid circular reference'}"
            elsif assc_sym != clas_sym
              "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}#{(should_be_trait || reflection.macro == :belongs_to) ? '' : '#'}association #{assc_sym.inspect}#{assc_sym != clas_sym ? ", factory: #{clas_sym.inspect}" : ''}#{should_be_trait ? '; end' : ''}#{should_be_trait || reflection.macro == :belongs_to ? '' : ' # commented to avoid circular reference'}"
            else
              "#{should_be_trait ? "trait #{"with_#{assc_sym}".to_sym.inspect} do; " : ''}#{(should_be_trait || reflection.macro == :belongs_to) ? '' : '#'}#{assc_sym}#{should_be_trait ? '; end' : ''}#{should_be_trait || reflection.macro == :belongs_to ? '' : ' # commented to avoid circular reference'}"
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
      
      if path.end_with?('.rb')
        dirpath = File.dirname(path)
        unless File.directory?(dirpath)
          puts "Please create this directory first: #{dirpath}"
          return false
        end

        File.open(path, "w") do |f|
          f.puts 'require \'factory_girl_rails\''
          f.puts ''
          f.puts 'FactoryGirl.define do'
          f.puts '  '            
          factories.keys.sort.each do |factory_name|
            factory = factories[factory_name]
            write_factory(factory_name, factory, f)
            f.puts '  '
          end
          f.puts "end"
        end
      else
        unless File.directory?(path)
          puts "Please create this directory first: #{path}"
          return false
        end

        factories.keys.sort.each do |factory_name|
          factory = factories[factory_name]
          File.open(File.join(path,"#{factory_name}.rb"), "w") do |f|
            f.puts 'require \'factory_girl_rails\''
            f.puts ''
            f.puts 'FactoryGirl.define do'
            f.puts '  '
            write_factory(factory_name, factory, f)
            f.puts '  '
            f.puts "end"
          end
        end
      end

      return true
    end

    private
    
    def self.write_factory(factory_name, factory, f)
      f.puts "  factory #{factory_name.inspect} do"
      factory.each do |line|
        f.puts "    #{line}"
      end
      f.puts "  end"
    end
  end
end
