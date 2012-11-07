require 'stepford/factory_girl'

module Stepford
  module FactoryGirlRspecHelpers
    [:create, :create_list, :build, :build_list, :build_stubbed].each do |s|
      class_eval %Q"
        def #{s}(*args, &block)
          ::Stepford::FactoryGirl.#{s}(*args, &block)
        end
      " 
    end
  end
end

RSpec.configure do |c|
  c.include ::Stepford::FactoryGirlRspecHelpers
end
