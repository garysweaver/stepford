module Stepford
  class << self
    attr_accessor :debug, :attr_match_test_data, :datatype_test_data
    def configure(&blk); class_eval(&blk); end
  end
end

Stepford.configure do
  @debug = true
  @attr_match_test_data = {
    /|*.\_at,*.\_on,|/ => Time.now
  }
  @datatype_test_data = {
    string: lambda{|c|generate(:random_string)},
    integer: lambda{|c|Random.rand(9999)},
    decimal: lambda{|c|Random.rand(9999.9)},
    datetime: Time.now,
    timestamp: Time.now,
    time: Time.now,
    date: Time.now,
    binary: Random.bytes(8),
    boolean: true,
    xml: lambda{|c|"<test>#{generate(:random_string)}</test>"},
    ts_vector: nil
  }
end
