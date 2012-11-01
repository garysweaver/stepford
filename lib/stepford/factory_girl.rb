require 'factory_girl'
require 'stepford/common'

module Stepford
  class FactoryGirl
    def self.generate_factories(options={})
      factories = {}

      expected = {}
      Dir[File.join('app','models','*.rb').to_s].each do |filename|
        model_name = File.basename(filename).sub(/.rb$/, '')
        load File.join('app','models',"#{model_name}.rb")
        model_class = model_name.camelize.constantize
        next unless model_class.ancestors.include?(ActiveRecord::Base)
        factory = (factories[model_name.to_sym] ||= [])
        foreign_keys = []
        model_class.reflections.collect {|a,b| (expected[b.class_name.underscore.to_sym] ||= []) << model_name; foreign_keys << b.foreign_key.to_sym; "association #{b.name.to_sym.inspect}, factory: #{b.class_name.underscore.to_sym.inspect}"}.sort.each {|l|factory << l}
        model_class.columns.collect {|c| "#{c.name.to_sym} #{Stepford::Common.value_for(c.name, c.type)}" unless foreign_keys.include?(c.name.to_sym)}.compact.sort.each {|l|factory << l}
      end

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
