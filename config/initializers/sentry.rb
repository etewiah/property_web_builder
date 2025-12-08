# frozen_string_literal: true

# Sentry configuration for error tracking and performance monitoring
# Set SENTRY_DSN environment variable to enable

if ENV['SENTRY_DSN'].present?
  Sentry.init do |config|
    config.dsn = ENV['SENTRY_DSN']

    # Set the environment
    config.environment = ENV.fetch('SENTRY_ENVIRONMENT', Rails.env)

    # Set the release version (useful for tracking deployments)
    config.release = ENV['APP_VERSION'] ||
                     ENV['GIT_COMMIT'] ||
                     `git rev-parse --short HEAD 2>/dev/null`.strip.presence ||
                     'unknown'

    # Enable breadcrumbs for better context
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]

    # Performance monitoring (traces)
    # Set to a lower value in production to reduce costs
    config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', 0.1).to_f

    # Profile a percentage of sampled transactions
    config.profiles_sample_rate = ENV.fetch('SENTRY_PROFILES_SAMPLE_RATE', 0.1).to_f

    # Send PII (Personally Identifiable Information) - disable in production if needed
    config.send_default_pii = ENV.fetch('SENTRY_SEND_PII', 'false') == 'true'

    # Filter sensitive parameters
    config.before_send = lambda do |event, hint|
      # Filter out health check errors (they can be noisy)
      if hint[:exception].is_a?(ActionController::RoutingError)
        path = event.request&.url || ''
        return nil if path.include?('/health')
      end

      # Add tenant context if available
      if defined?(Pwb::Current) && Pwb::Current.website
        event.tags[:tenant_subdomain] = Pwb::Current.website.subdomain
        event.tags[:tenant_id] = Pwb::Current.website.id
      end

      # Add user context if available
      if defined?(current_user) && current_user
        event.user = {
          id: current_user.id,
          email: current_user.email
        }
      end

      event
    end

    # Exclude common noisy exceptions
    config.excluded_exceptions += [
      'ActionController::RoutingError',
      'ActionController::InvalidAuthenticityToken',
      'ActionController::BadRequest',
      'ActionDispatch::Http::MimeNegotiation::InvalidType',
      'Rack::QueryParser::InvalidParameterError',
      'Rack::QueryParser::ParameterTypeError'
    ]

    # Environment-specific settings
    case Rails.env
    when 'development'
      # In development, you might want to see errors locally
      config.traces_sample_rate = 1.0
      config.debug = true
    when 'test'
      # Disable Sentry in test environment
      config.enabled_environments = []
    when 'production', 'staging'
      # In production, sample a percentage of transactions
      config.traces_sample_rate = ENV.fetch('SENTRY_TRACES_SAMPLE_RATE', 0.1).to_f
    end
  end

  Rails.logger.info "[Sentry] Initialized for environment: #{Rails.env}"
else
  Rails.logger.info "[Sentry] Not configured - set SENTRY_DSN to enable error tracking"
end
