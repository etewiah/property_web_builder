ENV["RAILS_ENV"] ||= "test"

require "simplecov"
# SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
SimpleCov.start :rails do
  add_filter do |source_file|
    source_file.lines.count < 5
  end
end

# require File.expand_path("../dummy/config/environment.rb", __FILE__)
require File.expand_path("../../config/environment", __FILE__)
require "rspec/rails"
# require 'rspec/autorun'
require "factory_bot_rails"
require "capybara/poltergeist"
# require 'capybara/rails'
require "pwb/seeder"
# http://www.thegreatcodeadventure.com/stubbing-with-vcr/
require "vcr"
require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)
# load(Rails.root.join("db", "seeds.rb"))

# # Configure capybara for integration testing
# # Capybara.default_driver = :rack_test
# # Capybara.default_selector = :css
# # js_options = {js_errors: false}
# # above is sometimes useful to troubleshoot errors with tests
# Capybara.register_driver :poltergeist do |app|
#   # set the timeout to a minute because it seems the first
#   # capybara tests were running in travis before assets
#   # had recompiled
#   js_options = {
#     debug: true,
#     # timeout: 30,
#     timeout: 1.minute,
#     window_size: [1280, 1440],
#     port: 44678 + ENV['TEST_ENV_NUMBER'].to_i,
#     phantomjs_options: [
#       '--proxy-type=none',
#       '--load-images=no',
#       '--ignore-ssl-errors=yes',
#       '--ssl-protocol=any',
#       '--web-security=false', '--debug=true'
#     ]
#   }

#   Capybara::Poltergeist::Driver.new(app, js_options)
# end
# Capybara.javascript_driver = :poltergeist
# # Capybara.ignore_hidden_elements = false

require "capybara/apparition"

Capybara.register_driver :apparition do |app|
  options = {}
  Capybara::Apparition::Driver.new(app, options)
end

# http://stackoverflow.com/questions/24078768/argumenterror-factory-not-registered
# as per above, need to explicitly set below
# FactoryBot.definition_file_paths = [File.expand_path("../factories", __FILE__)]
# FactoryBot.find_definitions
# July 2022 - above no longer required

Rails.backtrace_cleaner.remove_silencers!

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# ActionController::Base.prepend_view_path "#{Rails.root}/app/themes/default/views/"
# replaced above with below in view specs so I can test diff themes
# @controller.prepend_view_path "#{Rails.root}/app/themes/berlin/views/"

RSpec.configure do |config|
  config.file_fixture_path = "spec/fixtures"
  # Above needed because of the following change:
  # https://til.hashrocket.com/posts/lhyrslsbhx-rails-change-fixture-file-lookup-path

  # TODO: - consider precompiling assets to speed up tests
  # config.before(:suite) do
  #   Rails.application.load_tasks
  #   Rake::Task["assets:precompile"].invoke
  # end

  config.include JsonSpec::Helpers

  config.mock_with :rspec
  config.infer_base_class_for_anonymous_controllers = false
  config.order = "random"
  # config.include Pwb::ApplicationHelper
  # config.include Rails.application.routes.url_helpers
  # config.include Rails.application.routes.url_helpers

  config.use_transactional_fixtures = false
  #
  # Make sure the database is clean and ready for test
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
    # Pwb::Seeder.seed!
  end

  config.after(:all) do
    # http://renderedtext.com/blog/2012/10/10/cleaning-up-after-before-all-blocks/
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, js: true) do
    # truncation is slower but more reliable
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
