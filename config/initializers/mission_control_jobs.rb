# frozen_string_literal: true

# Mission Control Jobs 1.0+ requires authentication configuration
# See: https://github.com/rails/mission_control-jobs#authentication

Rails.application.configure do
  # Use HTTP Basic authentication for the jobs dashboard
  # Credentials can be set via environment variables
  config.mission_control.jobs.http_basic_auth_enabled = true
  config.mission_control.jobs.http_basic_auth_user = ENV.fetch("JOBS_AUTH_USER", "admin")
  config.mission_control.jobs.http_basic_auth_password = ENV.fetch("JOBS_AUTH_PASSWORD") { SecureRandom.hex(16) }
end
