module Stepford
  class CircularRefChecker

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
        
        begin
          model_class = model_name.camelize.constantize
        rescue => e
          puts "Problem in #{model_name.camelize}"
          raise e
        end

        next unless model_class.ancestors.include?(ActiveRecord::Base)
        models << model_class
      end

      models.each do |model_class|
        check_associations(model_class)
      end

      if @@circles.size == 0
        puts
        puts "No circular dependencies."
        puts
        return true
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
      puts

      return false
    end

    def self.check_associations(model_class, model_and_association_names = [])
      model_class.reflections.collect {|association_name, reflection|
        puts "warning: #{model_class}'s association #{reflection.name}'s foreign_key was nil. can't check." unless reflection.foreign_key
        assc_sym = reflection.name.to_sym
        
        begin
          next_class = reflection.class_name.constantize
        rescue => e
          puts "Problem in #{model_class.name} with association: #{reflection.macro} #{assc_sym.inspect} which refers to class #{reflection.class_name}"
          raise e
        end

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
          key = [model_class.table_name.to_sym, reflection.foreign_key.to_sym, next_class.table_name.to_sym]
          if model_and_association_names.include?(key)
            @@offenders << model_and_association_names.last unless @@offenders.include?(model_and_association_names.last)
            short = model_and_association_names.dup
            # drop all preceding keys that have nothing to do with the circle
            (short.index(key)).times {short.delete_at(0)}
            sorted = short.sort
            unless @@circles_sorted.include?(sorted)
              @@circles_sorted << sorted
              @@circles << "#{(short + [key]).collect{|b|"#{b[0]}.#{b[1]}"}.join(' -> ')}".to_sym
            end
          else
            model_and_association_names << key
            check_associations(next_class, model_and_association_names)
          end
        end
      }

      model_and_association_names.pop
      model_and_association_names
    end
  end
end
