require 'thor'

module Stepford
  class CLI < Thor
    desc "factories", "create FactoryGirl factories"
    method_option :single, :desc => "Put all factories into a single file", :type => :boolean
    method_option :path, :desc => "Pathname of file to contain factories or path of directory to contain factory/factories"
    method_option :associations, :desc => "Include associations in factories", :type => :boolean
    method_option :validate_associations, :desc => "Validate associations in factories even if not including associations", :type => :boolean
    method_option :exclude_all_ids, :desc => "Exclude attributes with names ending in _id even if they aren't foreign or primary keys", :type => :boolean
    method_option :models, :desc => "A comma delimited list of only the models you want to include"
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
