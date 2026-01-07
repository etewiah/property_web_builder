# frozen_string_literal: true

return unless defined?(PgHero)

PgHero.env = Rails.env

if defined?(PgHero::Engine)
  restricted_env = Rails.env.production? || Rails.env.staging?

  if restricted_env
    username = ENV["PGHERO_USERNAME"]
    password = ENV["PGHERO_PASSWORD"]

    if username.present? && password.present?
      PgHero::Engine.middleware.use Rack::Auth::Basic do |provided_username, provided_password|
        ActiveSupport::SecurityUtils.secure_compare(provided_username, username) &&
          ActiveSupport::SecurityUtils.secure_compare(provided_password, password)
      end
    else
      Rails.logger.warn("PgHero basic auth disabled: set PGHERO_USERNAME and PGHERO_PASSWORD")
    end
  end
end
