module Stepford
  class Common
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
        column.default.nil? ? '<test>Test #{column_name.titleize}</test>' : column.default.to_s
      when :ts_vector
        column.default.nil? ? 'nil' : column.default.to_s
      else
        puts "Stepford does not know how to handle type #{column.type.to_sym}"
        column.default.nil? ? 'nil' : column.default.to_s
      end
    end
  end
end
