source 'https://rubygems.org'

# Declare your gem's dependencies in pwb.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

gem 'rails', '~> 5.1.1'
# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# gem 'globalize', git: 'https://github.com/globalize/globalize'
# gem 'globalize', github: 'globalize/globalize'
# below needed by above - (in gemspec)
# gem 'activemodel-serializers-xml'
# gem 'globalize-accessors'
# gem 'carrierwave', '>= 1.0.0.rc', '< 2.0'

# To use a debugger
# gem 'byebug', group: [:development, :test]
group :development, :test do
  # gem 'jasmine-rails',        github: 'searls/jasmine-rails'
  # gem 'jasmine-jquery-rails', github: 'travisjeffery/jasmine-jquery-rails'
  # if ENV['TRAVIS']
  #   gem "codeclimate-test-reporter", require: false
  # else
  #   gem 'simplecov',                 require: false
  # end
  gem 'simplecov',                 require: false
  unless ENV['CI']
    # uncommenting below will result in travis ci prompting me to Run `bundle install` elsewhere and add the
    # updated Gemfile.lock to version control
    # gem 'launchy'
    # gem 'annotate'
    # gem 'bumpy'
    # gem 'yard'
    # gem 'redcarpet'
    # gem 'spring'
    # gem 'spring-commands-rspec'
  end

  gem 'launchy'
  # launchy allows me to use save_and_open_page
  # in feature specs to see current page being tested
  gem 'rubocop', require: false
  gem 'pry-byebug'
  gem 'capybara'
  gem 'database_cleaner'
  # , '~> 1.3'
  gem 'rails-controller-testing'
  gem 'factory_girl_rails'
  gem 'poltergeist'
  # , '~> 1.10'
  # gem 'rspec-activemodel-mocks', '~> 1.0'
  gem 'rspec-rails'
  gem 'shoulda-matchers'
  gem 'font-awesome-rails'
  gem 'guard'
  gem 'guard-rspec', require: false
  gem 'zeus'
  gem 'json_spec'

  gem 'rails-perftest'
  gem 'ruby-prof', '0.15.9'
end

group :development do
  gem 'guard-rubocop'
  # below 2 for precompiling assets
  gem 'closure-compiler'
  gem 'yui-compressor'
end


# /Users/me/.rbenv/versions/2.3.3/lib/ruby/gems/2.3.0/gems/localeapp-2.1.1/lib/localeapp/default_value_handler.rb
# below overwrites I18n::Backend::Base above which causes seeder to break in specs
# gem 'localeapp'

gem 'paloma', github: 'fredngo/paloma'
# gem 'bourbon'
# gem 'property_web_scraper', github: 'RealEstateWebTools/property_web_scraper'

gem 'sassc-rails'
gem "omniauth-rails_csrf_protection"
# capybary now requires puma as webserver by default
gem 'puma'
