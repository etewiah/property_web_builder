# frozen_string_literal: true

# Rails Performance - Self-hosted APM dashboard
# Dashboard available at /rails/performance
#
# Features:
# - Request throughput and response times
# - Slow endpoint detection
# - Database query monitoring
# - Custom event tracking
#
# Data is stored in Redis and never sent externally.

# Disable the resource monitor logging (CPU/memory/disk every minute) by default
# This prevents noisy "Server: ..., Context: rails, Role: web, data: ..." logs
# To enable, set RAILS_PERFORMANCE_RESOURCE_MONITOR=true
RailsPerformance._resource_monitor_enabled = ENV['RAILS_PERFORMANCE_RESOURCE_MONITOR'] == 'true'

# If the engine already started the monitor, stop it
if !RailsPerformance._resource_monitor_enabled && RailsPerformance._resource_monitor
  RailsPerformance._resource_monitor.stop_monitoring rescue nil
end

RailsPerformance.setup do |config|
  # Redis configuration - uses the same Redis as the rest of the app
  config.redis = Redis.new(
    url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  )

  # How long to keep performance data (in hours)
  # Default is 4 hours, we keep 7 days for trend analysis
  config.duration = 168.hours

  # Debug mode enables verbose logging (e.g. [SAVE] entries for every record)
  # Controlled via environment variable for easier toggling without code changes
  config.debug = ENV['RAILS_PERFORMANCE_DEBUG'] == 'true'

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
    '/rails/performance',
    '/jobs',
    '/logs',
    '/active_storage_dashboard',

    # Active Storage (file uploads can be slow, not useful to track)
    '/rails/active_storage',

    # Chrome DevTools
    '/.well-known/appspecific/com.chrome.devtools.json'
  ]

  # Custom user identification for tracking
  # Returns a hash with tenant and user context
  config.custom_data_proc = ->(env) {
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

  # Track rake tasks (useful for debugging slow seeds, migrations)
  config.include_rake_tasks = Rails.env.development?

  # Enable custom events tracking
  config.include_custom_events = true
end

# Fine-grained logging control for Rails Performance
# This allows us to suppress noisy [SAVE] messages while still seeing other debug info
module RailsPerformance
  class << self
    def log(message)
      return unless RailsPerformance.debug

      # Skip noisy [SAVE] logs unless specifically requested via environment variable
      # These logs occur every time a record is saved to Redis
      if message.include?("[SAVE]") && ENV['RAILS_PERFORMANCE_VERBOSE'] != 'true'
        return
      end

      # Prefix the log message for easier filtering/identification
      formatted_message = "[RailsPerformance] #{message}"

      if ::Rails.logger
        ::Rails.logger.debug(formatted_message)
      else
        puts(formatted_message)
      end
    end
  end
end

# Monkey-patch ResourceMonitor to use our unified logging
# This ensures "Server: ..., Context: rails..." logs respect the debug setting
if defined?(RailsPerformance::SystemMonitor::ResourcesMonitor)
  module RailsPerformance
    module SystemMonitor
      class ResourcesMonitor
        def store_data(data)
          # Use our unified log method instead of direct Rails.logger.info
          # This allows us to suppress these logs unless RAILS_PERFORMANCE_DEBUG is true
          RailsPerformance.log("Server: #{server_id}, Context: #{context}, Role: #{role}, data: #{data}")

          now = RailsPerformance::Utils.kind_of_now
          now = now.change(sec: 0, usec: 0)
          RailsPerformance::Models::ResourceRecord.new(
            server: server_id,
            context: context,
            role: role,
            datetime: now.strftime(RailsPerformance::FORMAT),
            datetimei: now.to_i,
            json: data
          ).save
        end
      end
    end
  end
end
