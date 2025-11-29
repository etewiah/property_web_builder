source "https://rubygems.org"

# Declare your gem's dependencies in pwb.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
# gemspec

gem "rails", "~> 8.0"
# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

ruby "3.4.7"

# gem 'globalize', git: 'https://github.com/globalize/globalize'
# gem 'globalize', github: 'globalize/globalize'
# below needed by above - (in gemspec)
# gem 'activemodel-serializers-xml'
# gem 'globalize-accessors'
# gem 'carrierwave', '>= 1.0.0.rc', '< 2.0'

# To use a debugger
# gem 'byebug', group: [:development, :test]
group :development, :test do
  gem "selenium-webdriver"
  gem "vcr"
  gem "webmock"
  # gem 'jasmine-rails',        github: 'searls/jasmine-rails'
  # gem 'jasmine-jquery-rails', github: 'travisjeffery/jasmine-jquery-rails'
  # if ENV['TRAVIS']
  #   gem "codeclimate-test-reporter", require: false
  # else
  #   gem 'simplecov',                 require: false
  # end
  gem "simplecov", require: false
  unless ENV["CI"]
    # uncommenting below will result in travis ci prompting me to Run `bundle install` elsewhere and add the
    # updated Gemfile.lock to version control
    # gem 'launchy'
    # gem 'annotate'
    gem 'annotaterb'
    # gem 'bumpy'
    # gem 'yard'
    # gem 'redcarpet'
    # gem 'spring'
    # gem 'spring-commands-rspec'
  end

  gem "launchy"
  # launchy allows me to use save_and_open_page
  # in feature specs to see current page being tested
  gem "rubocop", require: false
  gem "pry-byebug"
  gem "capybara"
  gem "database_cleaner"
  # , '~> 1.3'
  gem "rails-controller-testing"
  gem "factory_bot_rails"
  gem "poltergeist"
  # , '~> 1.10'
  # gem 'rspec-activemodel-mocks', '~> 1.0'
  gem "rspec-rails"
  gem "shoulda-matchers"
  gem "font-awesome-rails"
  gem "guard"
  gem "guard-rspec", require: false
  gem "zeus"
  gem "json_spec"

  gem "rails-perftest"
  gem "ruby-prof"

  gem "apparition"
  gem "rswag-specs"
end

gem "rswag-api"
gem "rswag-ui"

group :development do
  gem "guard-rubocop"
  # below 2 for precompiling assets
  gem "closure-compiler"
  gem "yui-compressor"

  gem "better_errors"
  gem "binding_of_caller"
  gem "bullet"
  gem "brakeman"
  gem "rack-mini-profiler"
  gem "dotenv-rails"
  gem "faker"
end

gem "oj"

# /Users/me/.rbenv/versions/2.3.3/lib/ruby/gems/2.3.0/gems/localeapp-2.1.1/lib/localeapp/default_value_handler.rb
# below overwrites I18n::Backend::Base above which causes seeder to break in specs
# gem 'localeapp'

# gem 'paloma', github: 'fredngo/paloma'
gem "paloma", "~> 6.1.0"
# gem 'bourbon'
# gem 'property_web_scraper', github: 'RealEstateWebTools/property_web_scraper'


# capybary now requires puma as webserver by default
gem "puma"

gem "pg" #, "~> 0.21.0"

gem "carrierwave", "~> 2.2"

gem "cloudinary", "~> 1.23"

gem "devise", "~> 4.8"

gem "omniauth", "~> 2.1"

gem "geocoder", "~> 1.8"

gem "i18n", "~> 1.10"

gem "i18n-active_record", "~> 1.1"

gem 'globalize', git: 'https://github.com/globalize/globalize'
# gem "globalize", "~> 6.2"

gem "money-rails", "~> 1.15"

gem "simple_form", "~> 5.1"

gem "jsonapi-resources", "~> 0.10.7"

gem "globalize-accessors", "~> 0.3.0"

gem "active_hash", "~> 3.1"

gem "flag_shih_tzu", "~> 0.3.23"

# gem "bootstrap-sass", "~> 3.4"
gem "dartsass-rails"
gem "sprockets-rails"

gem "jquery-rails", "~> 4.5"

gem "liquid", "~> 5.3"

# https://stackoverflow.com/questions/71191685/visit-psych-nodes-alias-unknown-alias-default-psychbadalias
# As per above, need to fix psych gem below v4
# gem "psych", "< 4"

gem "vite_rails", "~> 3.0"

gem "graphql", "~> 2.0"
gem "graphiql-rails", group: :development

gem "faraday", "~> 2.3"

gem "rets", "~> 0.11.2"

gem "rack-cors", "~> 1.1"

gem "redis", "~> 4.7"
# redis gem needs to be before logster
gem "logster", "~> 2.11"

gem "ruby_odata", "~> 0.1.0"

gem "firebase"
gem "omniauth-facebook"

gem "tailwindcss-rails", "~> 4.4"

gem "firebase_id_token", "~> 2.5"

gem "annotaterb"
