# frozen_string_literal: true

# Set default URL options for ActiveStorage
# This is required when generating URLs outside of a request context
# (e.g., Rails console, background jobs, rake tasks)
#
# Without this, the Disk service will raise:
#   ArgumentError: Cannot generate URL for X using Disk service,
#   please set ActiveStorage::Current.url_options
#
# Note: ActiveStorage::Current is a CurrentAttributes class that resets per-request.
# We use prepend_before_action via a concern to set it on every request,
# plus after_initialize for non-request contexts (console, jobs, rake tasks).

# For non-request contexts (console, background jobs, rake tasks)
Rails.application.config.after_initialize do
  ActiveStorage::Current.url_options = Rails.application.routes.default_url_options.presence || {
    host: ENV.fetch("APP_HOST") { ENV.fetch("MAILER_HOST", "localhost") },
    port: Rails.env.development? ? 3000 : nil,
    protocol: Rails.env.production? ? "https" : "http"
  }
end

# Concern to set ActiveStorage URL options on every request
# This handles the per-request reset of CurrentAttributes
module ActiveStorageUrlOptionsSetter
  extend ActiveSupport::Concern

  included do
    prepend_before_action :set_active_storage_url_options
  end

  private

  def set_active_storage_url_options
    ActiveStorage::Current.url_options = {
      host: request.host,
      port: request.port,
      protocol: request.protocol.delete("://")
    }
  end
end

# Include in ApplicationController after Rails loads
Rails.application.config.to_prepare do
  # Include in all controllers that might generate ActiveStorage URLs
  ActionController::Base.include(ActiveStorageUrlOptionsSetter)
end
