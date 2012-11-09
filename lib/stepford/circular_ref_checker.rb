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

      puts "The following non-nullable foreign keys used in ActiveRecord model associations are involved in circular dependencies:"
      @@circles.sort.each do |c|
        puts
        puts "#{c}"
      end
      puts
      puts
      puts "Distinct foreign keys involved in a circular dependency:"
      puts
      @@offenders.sort.each do |c|
        puts "#{c[0]}.#{c[1]}"
      end

      totals = {}
      @@circles_sorted.each do |arr|
        arr.each do |key|
          totals[key] = 0 unless totals[key]
          totals[key] = totals[key] + 1
        end
      end
      puts
      puts
      puts "Foreign keys by number of circular dependency chains involved with:"
      puts
      totals.sort_by {|k,v| v}.reverse.each do |arr|
        c = arr[0]
        t = arr[1]
        puts "#{t} (out of #{@@circles_sorted.size}): #{c[0]}.#{c[1]} -> #{c[2]}"
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
        next_class = clas_sym.to_s.camelize.constantize

        # if has a foreign key, then if NOT NULL or is a presence validate, the association is required and should be output. unfortunately this could mean a circular reference that will have to be manually fixed
        has_presence_validator = model_class.validators_on(assc_sym).collect{|v|v.class}.include?(ActiveModel::Validations::PresenceValidator)
        required = reflection.foreign_key ? (has_presence_validator || model_class.columns.any?{|c| !c.null && c.name.to_sym == reflection.foreign_key.to_sym}) : false
        if required
          key = [model_class.table_name.to_sym, reflection.foreign_key.to_sym, next_class.table_name]
          if @@model_and_association_names.include?(key)
            @@offenders << @@model_and_association_names.last unless @@offenders.include?(@@model_and_association_names.last)
            short = @@model_and_association_names.dup
            # drop all preceding keys that have nothing to do with the circle
            (short.index(key)).times {short.delete_at(0)}
            sorted = short.sort
            unless @@circles_sorted.include?(sorted)
              @@circles_sorted << sorted
              @@circles << "#{(short << key).collect{|b|"#{b[0]}.#{b[1]}"}.join(' -> ')}".to_sym
            end
          else
            @@model_and_association_names << key
            check_associations(next_class)
          end
        end
      }

      @@level -= 1
    end
  end
end
