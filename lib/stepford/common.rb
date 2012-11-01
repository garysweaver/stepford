module Stepford
  class Common
    def self.value_for(column_name, type)
      case type
      when :string
        "'Test #{column_name.titleize}'"
      when :integer
        '123'
      when :decimal
        '1.23'
      when :datetime
        '{ 2.weeks.ago }'
      when :timestamp
        '{ 2.weeks.ago }'
      when :binary
        '0b010101'
      when :boolean
        'true'
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
