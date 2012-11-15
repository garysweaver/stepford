module Stepford
  # Needed a column representation that would allow user to specify attributes that are used for sample data choice for virtual attributes
  # e.g. if you have an object_id column in the schema, but in model you have virtual proxy attribute methods to set it like my_object_id/my_object_id=
  # then you need a way to specify that it should set my_object_id= with a string vs. number, etc.
  class ColumnRepresentation
    attr_accessor :name, :type, :limit, :default, :null, :precision, :scale, :virtual

    def initialize(args)
      if args.is_a?(Symbol)
        @name = args.to_sym
      elsif !(args.nil?)
        # assume initializing with column
        # see: http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/TableDefinition.html#method-i-column
        @name = args.name
        @type = args.type
        @limit = args.limit
        @default = args.default
        @null = args.null # should be called nullable, but using what Rails/AR calls it to be easier to work with as if were a "real" AR column
        @precision = args.precision
        @scale = args.scale
      end
    end

    def merge_options(options)
      options.each {|k,v|instance_variable_set("@#{k}", v)}
    end
  end
end
