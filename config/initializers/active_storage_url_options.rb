# frozen_string_literal: true

# Set default URL options for ActiveStorage
# This is required when generating URLs outside of a request context
# (e.g., Rails console, background jobs, rake tasks)
#
# Without this, the Disk service will raise:
#   ArgumentError: Cannot generate URL for X using Disk service,
#   please set ActiveStorage::Current.url_options

Rails.application.config.after_initialize do
  ActiveStorage::Current.url_options = {
    host: ENV.fetch("APP_HOST") { ENV.fetch("MAILER_HOST", "localhost") },
    protocol: Rails.env.production? ? "https" : "http"
  }
end
