require_relative "production"

Rails.application.configure do
  # Use a dedicated host for staging emails and generated links.
  config.action_mailer.default_url_options = {
    host: ENV.fetch("MAILER_HOST") do
      ENV.fetch("STAGING_APP_HOST") { ENV.fetch("APP_HOST", "staging.example.com") }
    end,
    protocol: ENV.fetch("STAGING_APP_PROTOCOL", "https")
  }
end
