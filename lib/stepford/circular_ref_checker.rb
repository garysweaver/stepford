module Stepford
  class CircularRefChecker

    @@model_and_association_names = []
    @@level = 0
    @@offenders = []
    @@circles_sorted = []
    @@circles = []
    @@selected_offenders = []

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
      puts "All foreign keys involved in a circular dependency:"
      puts
      @@offenders.sort.each do |c|
        puts "#{c[0]}.#{c[1]}"
      end
      puts
      puts
      puts "Arbitrarily chosen foreign_keys involved in a circular dependency that would break each circular dependency chain if marked as nullable. It would be a better idea to examine the full list of foreign keys and circles above, fix, then rerun:"
      puts
      @@selected_offenders.sort.each do |c|
        puts "#{c[0]}.#{c[1]}"
      end

      return (@@offenders.size == 0)
    end

    def self.check_associations(model_class)
      @@level += 1

      model_class.reflections.collect {|association_name, reflection|
        @@model_and_association_names = [] if @@level == 1
        next unless reflection.macro == :belongs_to
        assc_sym = reflection.name.to_sym
        clas_sym = reflection.class_name.underscore.to_sym

        # if has a foreign key, then if NOT NULL or is a presence validate, the association is required and should be output. unfortunately this could mean a circular reference that will have to be manually fixed
        has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(ActiveModel::Validations::PresenceValidator)
        required = reflection.foreign_key ? (has_presence_validator || model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym}) : false
        if required
          key = [model_class.to_s.underscore.to_sym, assc_sym]
          if @@model_and_association_names.include?(key)
            @@offenders << @@model_and_association_names.last unless @@offenders.include?(@@model_and_association_names.last)
            short = @@model_and_association_names.dup
            # drop all preceding keys that have nothing to do with the circle
            (short.index(key)).times {short.delete_at(0)}
            sorted = short.sort
            unless @@circles_sorted.include?(sorted)
              @@circles_sorted << sorted
              last_key_in_circle_before_restart = short.last
              @@selected_offenders << last_key_in_circle_before_restart unless @@selected_offenders.include?(last_key_in_circle_before_restart)
              @@circles << "#{(short << key).collect{|b|"#{b[0]}.#{b[1]}"}.join(' -> ')}".to_sym
            end
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
