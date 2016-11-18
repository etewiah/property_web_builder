source 'https://rubygems.org'

# Declare your gem's dependencies in pwb.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

gem 'globalize', github: 'globalize/globalize'
# below needed by above
gem 'activemodel-serializers-xml'
gem 'globalize-accessors'
gem 'carrierwave', '>= 1.0.0.rc', '< 2.0'

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
    # gem 'launchy'
    # gem 'annotate'
    # gem 'bumpy'
    # gem 'yard'
    # gem 'redcarpet'
    gem 'pry-byebug'
    # gem 'spring'
    # gem 'spring-commands-rspec'
    gem 'rubocop', require: false
  end
  gem 'capybara'
  # gem 'database_cleaner', '~> 1.3'
  gem 'rails-controller-testing'
  gem 'factory_girl_rails'
  # gem 'poltergeist', '~> 1.10'
  # gem 'rspec-activemodel-mocks', '~> 1.0'
  gem 'rspec-rails'
  gem 'shoulda-matchers'
end