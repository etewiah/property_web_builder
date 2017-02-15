require 'money-rails'
require 'globalize-accessors'
require 'bootstrap-sass'
require 'carrierwave'
require 'responders'
require 'jsonapi-resources'
# paloma gem results in
# DEPRECATION WARNING: before_filter is deprecated and will be removed in Rails 5.1
require 'paloma'
require 'jquery-rails'
require 'simple_form'
require 'devise'
require 'cloudinary'
require 'active_hash'
# require 'redis'
# # logster gem has to be after redis..
# require 'logster'
# require 'byebug'
# require 'fog/aws'
# require 'font-awesome-rails'
module Pwb
  class Engine < ::Rails::Engine
    isolate_namespace Pwb

    config.generators do |g|
      g.test_framework :rspec, fixture: false
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
      g.assets false
      g.helper false
    end

    config.action_dispatch.default_headers = {
      'X-Frame-Options' => 'ALLOWALL'
    }
    # config.assets.paths << File.expand_path("../../assets/stylesheets", __FILE__)
    # config.assets.paths << File.expand_path("../../assets/javascripts", __FILE__)
    config.assets.paths << root.join("app", "assets", "stylesheets", "pwb", "themes")
    config.assets.paths << root.join("app", "assets", "javascripts", "pwb", "themes")
    config.assets.precompile += %w( default.css chic.css oslo.css berlin.css default.js chic.js oslo.js berlin.js )

    config.to_prepare do
      # https://github.com/plataformatec/devise/wiki/How-To:-Use-devise-inside-a-mountable-engine
      Devise::SessionsController.layout "pwb/devise"
      Devise::RegistrationsController.layout "pwb/devise"
      # proc{ |controller| user_signed_in? ? "application" : "pwb/devise" }
      Devise::ConfirmationsController.layout "pwb/devise"
      Devise::UnlocksController.layout "pwb/devise"
      Devise::PasswordsController.layout "pwb/devise"
    end
  end
end
