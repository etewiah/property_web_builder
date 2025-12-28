# frozen_string_literal: true

# Check for PWB updates on application boot
#
# This runs asynchronously to avoid slowing down server startup.
# Only runs on first boot (not on Rails console or rake tasks).

Rails.application.config.after_initialize do
  # Only check in server context, not in console/rake/test
  next unless defined?(Rails::Server) || ENV['PWB_FORCE_VERSION_CHECK']

  # Skip in test environment
  next if Rails.env.test?

  # Run the check in a background thread to avoid blocking boot
  Thread.new do
    # Small delay to let the server finish initializing
    sleep 2

    begin
      Pwb::VersionCheckService.check_and_log
    rescue StandardError => e
      Rails.logger.debug "[PWB Version] Startup check failed: #{e.message}"
    end
  end
end
