require 'factory_girl'

module Stepford
  class FactoryGirl
    def self.define_factories(model_names)
      model_names = Array.wrap(model_names)
      if model_names.size > 0
        # Assume the people want them all so...
        # Load all the models and let's crap out if fails to load any models, as that is probably not a good thing
        Dir.glob(File.join(Rails.root, 'app', 'models', '*.rb').each { |file| require file }
        models = ActiveRecord::Base.descendants.collect { |type| type.name }.sort
      end

      puts "#{self} models: #{model_names.collect{|model_name|model_name.to_sym.inspect}.join(', ')}" if Stepford.debug
      model_names.each do |model_name|
        model_class = model_name.constantize
        FactoryGirl.define do
          factory model_name.to_sym do
            # auto-create associations to other factories
            model_class.reflect_on_all_associations.each do |a|
              association a.name.to_sym, factory: a.model_class.underscore.to_sym
            end

            # set all attributes with sample data
            model_class.columns.each do |c|
              send(c.name.to_sym, sample_data(c))
            end
          end
        end
      end
    end

    private

    def sample_data(column)
      Stepford.model_attr_match_test_data.keys.each do |rexp|
        puts "#{self} checking regexp #{rexp.to_s} to attempt match against column.name #{column.name}" if Stepford.debug
        if rexp ~= column.name
          puts "#{self} regexp #{rexp.to_s} matched column.name #{column.name}" if Stepford.debug
          return Stepford.attr_match_test_data[rexp]
        end
      end

      result = Stepford.model_datatype_test_data[c.type.to_sym]
      puts "#{self} using Stepford.datatype_test_data for type #{column.type.to_sym.inspect}: #{result}" if Stepford.debug
      result
  end
end
