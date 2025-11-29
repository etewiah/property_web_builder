require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Use a fixed secret key base for e2e environment
  # This is safe because it's only for local testing
  config.secret_key_base = 'e2e_test_secret_key_base_for_playwright_testing_only_not_for_production_use'

  # E2E testing environment - similar to development but isolated
  # This environment is optimized for running Playwright end-to-end tests

  # Make code changes take effect immediately without server restart.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Disable caching for consistent test behavior
  config.action_controller.perform_caching = false

  # Change to :null_store to avoid any caching.
  config.cache_store = :null_store

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Make template changes take effect immediately.
  config.action_mailer.perform_caching = false

  # Set localhost to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "localhost", port: 3001 }

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Append comments with runtime information tags to SQL queries in logs.
  config.active_record.query_log_tags_enabled = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Allow requests from localhost subdomains for multi-tenant testing
  config.hosts << ".lvh.me"
  config.hosts << "localhost"
  config.hosts << "tenant-a.e2e.localhost"
  config.hosts << "tenant-b.e2e.localhost"  
  # Configure subdomain detection for .e2e.localhost domains (TLD is "e2e.localhost" = 2 parts)
  # config.action_dispatch.tld_length = 2

  # Disable Bullet for cleaner test output
  config.after_initialize do
    Bullet.enable = false if defined?(Bullet)
  end

  # Log to stdout for easier debugging during test runs
  config.logger = ActiveSupport::Logger.new(STDOUT)
  config.log_level = :info
end
