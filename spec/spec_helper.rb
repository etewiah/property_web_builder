ENV['RAILS_ENV'] ||= 'test'

require 'simplecov'
SimpleCov.start

require File.expand_path('../dummy/config/environment.rb', __FILE__)
require 'rspec/rails'
# require 'rspec/autorun'
require 'factory_girl_rails'

# load(Rails.root.join("db", "seeds.rb"))

# http://stackoverflow.com/questions/24078768/argumenterror-factory-not-registered
# as per above, need to explicitly set below
FactoryGirl.definition_file_paths = [File.expand_path('../factories', __FILE__)]
FactoryGirl.find_definitions
# Oddly above does not occur if factory_girl_rails is only referrenced in pwb.gemspec
# but not main gemfile

Rails.backtrace_cleaner.remove_silencers!

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

ActionController::Base.prepend_view_path "#{Pwb::Engine.root}/app/themes/default/views/"

RSpec.configure do |config|
  config.mock_with :rspec
  config.use_transactional_fixtures = true
  config.infer_base_class_for_anonymous_controllers = false
  config.order = 'random'
  # config.include Pwb::ApplicationHelper
  # config.include Rails.application.routes.url_helpers
  # config.include Pwb::Engine.routes.url_helpers
end
