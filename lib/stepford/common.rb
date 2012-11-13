module Stepford
  class Common
    def self.sequence_for(column)
      case column.type
      when :string, :text
        if column.name.to_s['email']
          # n evaluated at runtime, so pound escaped
          "sequence(#{column.name.to_sym.inspect}) do |n|; \"person\#{n}@example.com\"; end"
        else
          # n evaluated at runtime, so pound escaped
          "sequence(#{column.name.to_sym.inspect}) do |n|; \"Test #{column.name.titleize} \#{n}\"; end"
        end
      when :integer, :decimal, :float, :date, :datetime, :timestamp, :binary, :ts_vector, :boolean
        "sequence(#{column.name.to_sym.inspect})"
      when :xml
        "sequence(#{column.name.to_sym.inspect}) do |n|; \"<test>Test #{column.name.titleize} \#{n}</test>\"; end"
      else
        puts "Stepford does not know how to generate a sequence value for column type #{column.type.to_sym}"
        column.default.nil? ? 'nil' : column.default.to_s
      end
    end
    def self.value_for(column)
      case column.type
      when :string, :text
        if column.default.nil?
          result = "Test #{column.name.titleize}"
          column.limit && column.limit < result.size ? (column.limit >= 0 ? "'#{'a' * column.limit}'" : 'nil') : "'#{result}'"
        else
          "'#{column.default}'"
        end
      when :integer
        column.default.nil? ? (column.limit ? column.limit.to_s : '123') : column.default.to_s
      when :decimal, :float
        column.default.nil? ? (column.limit ? column.limit.to_s : '1.23') : column.default.to_s
      when :date, :datetime, :timestamp
        '{ 2.weeks.ago }'
      when :binary
        column.default.nil? ? (column.limit ? column.limit.to_s : '0b010101') : column.default.to_s
      when :boolean
        column.default.nil? ? 'true' : column.default.to_s
      when :xml
        column.default.nil? ? '<test>Test #{column.name.titleize}</test>' : column.default.to_s
      when :ts_vector
        column.default.nil? ? 'nil' : column.default.to_s
      else
        puts "Stepford does not know how to generate a value for column type #{column.type.to_sym}"
        column.default.nil? ? 'nil' : column.default.to_s
      end
    end
  end
end
