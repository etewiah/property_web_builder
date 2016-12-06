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

    # config.to_prepare do
    #   # https://github.com/plataformatec/devise/wiki/How-To:-Use-devise-inside-a-mountable-engine
    #   Devise::SessionsController.layout "layout_for_sessions_controller"
    # end
  end
end
