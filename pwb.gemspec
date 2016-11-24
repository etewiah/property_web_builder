$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'pwb/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'pwb'
  s.version     = Pwb::VERSION
  s.authors     = ['Ed Tewiah']
  s.email       = ['etewiah@hotmail.cim']
  s.homepage    = 'http://propertywebbuilder.com'
  s.summary     = 'A Rails engine for real estate agents.'
  s.description = 'PropertyWebBuilder lets you build real estate websites fast.'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'rails', '~> 5.0.0', '>= 5.0.0.1'
  s.add_dependency 'money-rails'
  # s.add_dependency 'globalize', '~> 5.0.0'
  # cannot add globalize here till there is a rails 5
  # compatible tag
  s.add_dependency 'activemodel-serializers-xml'
  s.add_dependency 'globalize-accessors'
  s.add_dependency 'carrierwave', '>= 1.0.0.rc', '< 2.0'
  s.add_dependency 'bootstrap-sass'
  s.add_dependency 'i18n-active_record'
  # , :require => 'i18n/active_record'
  s.add_dependency 'responders'
  s.add_dependency 'jsonapi-resources'

  s.add_development_dependency 'byebug'
  s.add_development_dependency 'pg'

  # s.add_development_dependency 'rspec-rails'
  # s.add_development_dependency 'capybara'
  # s.add_development_dependency 'factory_girl_rails'
  # s.add_development_dependency 'rails-controller-testing'
end
