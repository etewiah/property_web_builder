ENV['RAILS_ENV'] ||= 'test'

require 'simplecov'
SimpleCov.start

require File.expand_path('../dummy/config/environment.rb', __FILE__)
require 'rspec/rails'
# require 'rspec/autorun'
require 'factory_girl_rails'

require 'capybara/poltergeist'
# require 'capybara/rails'

# load(Rails.root.join("db", "seeds.rb"))

# Configure capybara for integration testing
# Capybara.default_driver = :rack_test
# Capybara.default_selector = :css
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app)
end
Capybara.javascript_driver = :poltergeist
# Capybara.ignore_hidden_elements = false


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

  # Make sure the database is clean and ready for test
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end
end
