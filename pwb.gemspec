$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'pwb/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'pwb'
  s.version     = Pwb::VERSION
  s.authors     = ['Ed Tewiah']
  s.email       = ['etewiah@hotmail.com']
  s.homepage    = 'http://propertywebbuilder.com'
  s.summary     = 'A Rails engine for real estate agents.'
  s.description = 'PropertyWebBuilder lets you build great real estate websites fast.'
  s.license     = 'MIT'

  # s.files = `git ls-files`.split($/).reject { |fn| fn.start_with? "spec" }
  # below advices using above but I'm not convinced
  # https://stackoverflow.com/questions/25544137/how-to-reduce-the-size-of-a-gem

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'rails', '>= 5.1.0'
  s.add_dependency 'money-rails', '~>1'
  s.add_dependency 'globalize', '~> 5.1.0.beta2'
  # cannot add globalize here till there is a rails 5
  # compatible tag
  # spt 2017 - rails 5 now supported by globalize
  s.add_dependency 'activemodel-serializers-xml'
  s.add_dependency 'globalize-accessors'

  # s.add_dependency 'carrierwave', '1.0.0.beta'
  # had to fix carrierwave at 1.0.0.beta because of this issue:
  # https://github.com/cloudinary/cloudinary_gem/issues/221
  # spt 2017 - above has now been fixed
  s.add_dependency 'carrierwave'
  s.add_dependency 'bootstrap-sass'
  s.add_dependency 'i18n-active_record'
  # , :require => 'i18n/active_record'
  s.add_dependency 'responders'
  s.add_dependency 'jsonapi-resources', '0.8.1'
  # s.add_dependency 'paloma'
  s.add_dependency 'jquery-rails'
  s.add_dependency 'simple_form'
  s.add_dependency 'fog-aws'
  # , require: 'fog-aws'
  s.add_dependency 'pg', '< 1.0'
  s.add_dependency 'devise'
  s.add_dependency 'devise-i18n'
  s.add_dependency 'omniauth'
  s.add_dependency 'omniauth-facebook'
  # s.add_dependency 'omniauth-twitter'
  # s.add_dependency 'omniauth'
  s.add_dependency 'cloudinary'
  s.add_dependency 'rets'
  s.add_dependency 'active_hash'
  s.add_dependency 'nokogiri'
  s.add_dependency 'faraday'
  s.add_dependency 'ruby_odata'
  s.add_dependency 'firebase'
  s.add_dependency 'faker'
  s.add_dependency 'flag_shih_tzu'
  s.add_dependency 'liquid'
  s.add_dependency 'geocoder'

  # s.add_dependency 'comfortable_mexican_sofa', '~> 1.12.0'
  # s.add_dependency 'redis'
  # # logster gem has to be after redis..
  # s.add_dependency 'logster'
  # s.add_dependency 'google-cloud-translate'

  s.add_development_dependency 'byebug'
  s.add_development_dependency 'vcr'
  s.add_development_dependency 'webmock'
  # s.add_development_dependency 'airborne'
  # s.add_development_dependency 'json_matchers'

  # s.add_development_dependency 'rspec-rails'
  # s.add_development_dependency 'capybara'
  # s.add_development_dependency 'factory_girl_rails'
  # s.add_development_dependency 'rails-controller-testing'
end
