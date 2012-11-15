module Stepford
  module FactoryGirl
    OPTIONS = [:debug, :column_overrides, :config_loaded, :column_overrides_tree]

    class << self
      OPTIONS.each{|o|attr_accessor o; define_method("#{o}?".to_sym){!!send("#{o}")}}
      def configure(&blk); class_eval(&blk); end

      # Loads the configuration from config/stepford.rb or a specified pathname unless has already been loaded.
      def load_config(pathname = nil)
        if !(pathname || ::Stepford::FactoryGirl.config_loaded) || (pathname && ::Stepford::FactoryGirl.config_loaded.to_sym != pathname.to_sym)
          begin
            if pathname
              # load without checking if exists to raise error if user-specified file is missing
              force_configure(pathname)
            else
              pathname = Rails.root.join('config', 'stepford.rb').to_s
              if File.exist?(pathname)
                force_configure(pathname)
              end
            end
          rescue => e
            puts "Failed to load #{pathname}:\n#{e.message}#{e.backtrace.join("\n")}"
          end
        end
      end

      def force_configure(pathname)
        load pathname
        puts "Loaded #{pathname}"
        ::Stepford::FactoryGirl.config_loaded = pathname   
      end

      def column_overrides=(args)
        # to avoid a lot of processing overhead, we preprocess the arrays into a hash that would look ugly to the user, e.g.
        # {:model_name => {:attribute_name => {options or just empty}}}
        result = {}
        args.each do |k,v|
          if k.is_a?(Array) && k.size == 2 && v.is_a?(Hash)
            table_columns = (result[k[0].to_sym] ||= {})
            table_column_options = (table_columns[k[1].to_sym] ||= {})
            table_column_options.merge(v)
          else
            puts "Ignoring bad Stepford::FactoryGirl.column_overrides array value: #{a.inspect}. Should look like [:model_name, :attribute_name, {}]. See documentation for information on defining options hash."
          end
        end if args
        @column_overrides = args
        @column_overrides_tree = result
      end
    end
  end
end

::Stepford::FactoryGirl.load_config