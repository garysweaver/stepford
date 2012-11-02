module Stepford
  class Common
    def self.value_for(column)
      case column.type
      when :string
        if column.default.nil?
          result = "Test #{column.name.titleize}"
          column.limit && column.limit < result.size ? (column.limit >= 0 ? "'#{'a' * column.limit}'" : 'nil') : "'#{result}'"
        else
          "'#{column.default}'"
        end
      when :integer
        column.default.nil? ? (column.limit ? column.limit.to_s : '123') : column.default.to_s
      when :decimal
        column.default.nil? ? (column.limit ? column.limit.to_s : '1.23') : column.default.to_s
      when :datetime
        '{ 2.weeks.ago }'
      when :timestamp
        '{ 2.weeks.ago }'
      when :binary
        column.default.nil? ? (column.limit ? column.limit.to_s : '0b010101') : column.default.to_s
      when :boolean
        column.default.nil? ? 'true' : column.default.to_s
      when :xml
        '<test>Test #{column_name.titleize}</test>'
      when :ts_vector
        'nil'
      else
        'nil'
      end
    end
  end
end
