require 'stepford/factory_girl_cache'

module Stepford
  module FactoryGirlCacheRspecHelpers
    [:create, :create_list, :build, :build_list, :build_stubbed].each do |s|
      class_eval %Q"
        def cache_#{s}(*args, &block)
          ::Stepford::FactoryGirlCache.#{s}(*args, &block)
        end
      " 
    end
  end
end

RSpec.configure do |c|
  c.include ::Stepford::FactoryGirlCacheRspecHelpers
end
