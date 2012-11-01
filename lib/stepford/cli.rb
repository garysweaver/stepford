require 'thor'

module Stepford
  class CLI < Thor
    desc "factories", "create FactoryGirl factories"
    method_option :single, :desc => "Put all factories into a single file"
    method_option :path, :desc => "Pathname of file to contain factories or path of directory to contain factory/factories"
    def factories()
      # load Rails environment
      require './config/environment'
      # load FactoryGirl and generate factories
      require 'stepford/factory_girl'
      exit Stepford::FactoryGirl.generate_factories(options) ? 0 : 1
    end
  end
end

Stepford::CLI.start
