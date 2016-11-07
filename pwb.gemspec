$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "pwb/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "pwb"
  s.version     = Pwb::VERSION
  s.authors     = ["Ed Tewiah"]
  s.email       = ["etewiah@hotmail.cim"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of Pwb."
  s.description = "TODO: Description of Pwb."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", "~> 5.0.0", ">= 5.0.0.1"

  s.add_development_dependency "pg"

  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'factory_girl_rails'

end
