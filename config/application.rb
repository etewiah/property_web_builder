require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
# require "sprockets/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module StandalonePwb
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    config.middleware.insert_before 0, Rack::Cors do
      if ENV["RAILS_ENV"] == "production"
        allow do
          # https://github.com/cyu/rack-cors/issues/178
          # origins "*"
          # Use wildcard as above or add a list of acceptable origins below
          origins ""
          # resource "*", headers: :any, methods: [:get, :post, :options, :patch, :delete], expose: ["ETag"]
          # resource "*",
          #          headers: :any,
          #          methods: [:get, :post, :options, :patch, :delete, :put],
          #          expose: ["X-CSRF-Token"],
          #          credentials: true
        end
      else
        allow do
          origins "http://localhost:9100", "http://localhost:9000", "http://localhost:8080"
          # resource "*", headers: :any, methods: [:get, :post, :options, :patch, :delete], expose: ["ETag"]
          resource "*",
                   headers: :any,
                   methods: [:get, :post, :options, :patch, :delete, :put],
                   expose: ["X-CSRF-Token"],
                   credentials: true
          # expose: ["X-CSRF-Token"] above needed so csrf token header is available to external client:
          # https://glaucocustodio.github.io/2016/01/20/dont-forget-to-expose-headers-when-using-rack-cors/
        end
      end
    end
  end
end
