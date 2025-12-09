require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on Cloudflare R2 (see config/storage.yml for options).
  config.active_storage.service = :cloudflare_r2

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :mem_cache_store

  # Use Solid Queue for background job processing
  # This enables async email delivery and other background tasks
  config.active_job.queue_adapter = :solid_queue
  # Use same database for queue (simpler deployment, suitable for moderate load)
  # For high-volume, configure a separate :queue database in database.yml

  # Email delivery configuration
  # Raise delivery errors in production to catch configuration issues
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_caching = false

  # Use async delivery via Active Job (requires job queue adapter)
  config.action_mailer.deliver_later_queue_name = :mailers

  # Set host to be used by links generated in mailer templates.
  # Uses MAILER_HOST env var, falls back to APP_HOST or default
  config.action_mailer.default_url_options = {
    host: ENV.fetch("MAILER_HOST") { ENV.fetch("APP_HOST", "example.com") },
    protocol: "https"
  }

  # SMTP configuration via environment variables
  # Supports common providers: SendGrid, Mailgun, Amazon SES, Postmark, etc.
  #
  # Required env vars:
  #   SMTP_ADDRESS   - SMTP server address (e.g., smtp.sendgrid.net)
  #   SMTP_PORT      - SMTP port (typically 587 for TLS)
  #   SMTP_USERNAME  - SMTP username/API key
  #   SMTP_PASSWORD  - SMTP password/API secret
  #
  # Optional env vars:
  #   SMTP_DOMAIN    - HELO domain (defaults to MAILER_HOST)
  #   SMTP_AUTH      - Authentication type (defaults to :plain)
  #
  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address: ENV["SMTP_ADDRESS"],
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      domain: ENV.fetch("SMTP_DOMAIN") { ENV.fetch("MAILER_HOST") { ENV.fetch("APP_HOST", "example.com") } },
      authentication: ENV.fetch("SMTP_AUTH", "plain").to_sym,
      enable_starttls_auto: true
    }
  else
    # Fallback: log emails if SMTP not configured
    # This prevents errors but emails won't be delivered
    Rails.logger.warn "SMTP not configured - emails will be logged but not sent"
    config.action_mailer.delivery_method = :test
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
