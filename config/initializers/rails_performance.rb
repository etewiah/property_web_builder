# frozen_string_literal: true

# Rails Performance - Self-hosted APM dashboard
# Dashboard available at /performance (protected by TenantAdminConstraint)
#
# Features:
# - Request throughput and response times
# - Slow endpoint detection
# - Database query monitoring
# - Background job performance
# - Error tracking
# - System resource monitoring (CPU, memory, disk)
#
# Data is stored in Redis and never sent externally.

RailsPerformance.setup do |config|
  # Redis configuration - uses the same Redis as the rest of the app
  config.redis = Redis.new(
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  )

  # How long to keep performance data (in hours)
  # Default is 24 hours, we keep 7 days for trend analysis
  config.duration = 168.hours

  # Enable debug mode in development
  config.debug = Rails.env.development?

  # Ignore certain paths from tracking
  config.ignored_endpoints = [
    # Health checks (high volume, not useful)
    '/health',
    '/health/live',
    '/health/ready',
    '/health/details',

    # Assets and static files
    '/assets',
    '/packs',
    '/vite-dev',
    '/vite-test',

    # Admin dashboards (avoid recursive tracking)
    '/performance',
    '/jobs',
    '/logs',
    '/active_storage_dashboard',

    # Chrome DevTools
    '/.well-known/appspecific/com.chrome.devtools.json'
  ]

  # Skip certain paths from slow request detection
  # (e.g., file uploads that are intentionally slow)
  config.skipable_rails_patterns = [
    /\/rails\/active_storage\//
  ]

  # Include system resources in dashboard
  # Requires: sys-cpu, sys-filesystem, get_process_mem gems
  config.include_system_resources = true

  # Custom user identification for tracking
  # Returns a string identifier for the current user
  config.custom_data_proc = -> (env) {
    # Try to identify the user/tenant from the request
    request = Rack::Request.new(env)

    data = {}

    # Add tenant context if available
    if defined?(Pwb::Current) && Pwb::Current.website
      data[:tenant_id] = Pwb::Current.website.id
      data[:tenant] = Pwb::Current.website.subdomain
    end

    # Add user context from Warden/Devise if available
    if env['warden']&.user
      data[:user_id] = env['warden'].user.id
      data[:user_email] = env['warden'].user.email
    end

    data
  }

  # Enable background job tracking for Solid Queue
  config.include_jobs = true

  # Track rake tasks (useful for debugging slow seeds, migrations)
  config.include_rake_tasks = Rails.env.development?
end
