module Stepford
  class CircularRefChecker

    @@model_and_association_names = []
    @@level = 0
    @@offenders = []
    @@circles = []

    # Check refs on all models or models specified in comma delimited list in options like:
    #   Stepford.CircularRefChecker.check_refs models: 'user, post, comment'
    def self.check_refs(options={})
      models = []
      included_models = options[:models] ? options[:models].split(',').collect{|s|s.strip}.compact : nil
      Dir[File.join('app','models','*.rb').to_s].each do |filename|
        model_name = File.basename(filename).sub(/.rb$/, '')
        next if included_models && !included_models.include?(model_name)
        load File.join('app','models',"#{model_name}.rb")
        model_class = model_name.camelize.constantize
        next unless model_class.ancestors.include?(ActiveRecord::Base)
        models << model_class
      end

      models.each do |model_class|
        check_associations(model_class)
      end

      puts "Circles of shame:"
      @@circles.sort.each do |c|
        puts
        puts "#{c}"
      end
      puts
      puts
      puts "Possible offenders. Either set nullable to true on these fields, or see if any of the fields above can be nullable:"
      puts
      @@offenders.sort.each do |c|
        puts "#{c[0]}.#{c[1]}"
      end

      return (@@offenders.size == 0)
    end

    def self.check_associations(model_class)
      @@level += 1

      model_class.reflections.collect {|association_name, reflection|
        @@model_and_association_names = [] if @@level == 1
        assc_sym = reflection.name.to_sym
        clas_sym = reflection.class_name.underscore.to_sym

        # if has a foreign key, then if NOT NULL or is a presence validate, the association is required and should be output. unfortunately this could mean a circular reference that will have to be manually fixed
        has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(ActiveModel::Validations::PresenceValidator)
        required = reflection.foreign_key ? (has_presence_validator || model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym}) : false
        if required
          key = [model_class.to_s.underscore.to_sym, assc_sym]
          if @@model_and_association_names.include?(key)
            @@offenders << @@model_and_association_names.last unless @@offenders.include?(@@model_and_association_names.last)
            # add to end
            @@model_and_association_names << key
            short = @@model_and_association_names.dup
            # drop all preceding keys that have nothing to do with the circle
            (short.index(key)).times {short.delete_at(0)}
            string_representation = "#{short.collect{|b|"#{b[0]}.#{b[1]}"}.join(' -> ')}"
            #puts string_representation
            @@circles << string_representation.to_sym unless @@circles.include?(string_representation.to_sym)
          else
            @@model_and_association_names << key
            check_associations(reflection.class_name.constantize)
          end
        end
      }

      @@level -= 1
    end
  end
end
