# frozen_string_literal: true

# Lograge configuration for structured logging
# Converts Rails logs from verbose multi-line format to single-line JSON

Rails.application.configure do
  # Enable lograge for all environments except development (optional)
  config.lograge.enabled = ENV.fetch('LOGRAGE_ENABLED', Rails.env.production? || Rails.env.staging?).to_s == 'true'

  # Use JSON formatter for structured logs (great for log aggregators)
  config.lograge.formatter = Lograge::Formatters::Json.new

  # Include request parameters (filtered)
  config.lograge.custom_options = lambda do |event|
    options = {
      timestamp: Time.current.iso8601,
      request_id: event.payload[:request_id],
      host: event.payload[:host],
      remote_ip: event.payload[:remote_ip],
      user_agent: event.payload[:user_agent]
    }

    # Add tenant context if available
    if event.payload[:tenant_subdomain]
      options[:tenant_subdomain] = event.payload[:tenant_subdomain]
      options[:tenant_id] = event.payload[:tenant_id]
    end

    # Add user context if available
    if event.payload[:user_id]
      options[:user_id] = event.payload[:user_id]
      options[:user_email] = event.payload[:user_email]
    end

    # Add exception info if present
    if event.payload[:exception]
      exception_class, exception_message = event.payload[:exception]
      options[:exception] = {
        class: exception_class,
        message: exception_message
      }
      options[:exception_backtrace] = event.payload[:exception_object]&.backtrace&.first(10)
    end

    # Add custom parameters (filtered)
    if event.payload[:params].present?
      # Filter sensitive params
      filtered_params = filter_sensitive_params(event.payload[:params])
      options[:params] = filtered_params if filtered_params.any?
    end

    options.compact
  end

  # Add custom payload data from controllers
  config.lograge.custom_payload do |controller|
    payload = {
      host: controller.request.host,
      remote_ip: controller.request.remote_ip,
      user_agent: controller.request.user_agent,
      request_id: controller.request.request_id
    }

    # Add tenant context
    if defined?(Pwb::Current) && Pwb::Current.website
      payload[:tenant_subdomain] = Pwb::Current.website.subdomain
      payload[:tenant_id] = Pwb::Current.website.id
    end

    # Add user context
    if controller.respond_to?(:current_user, true) && controller.send(:current_user)
      user = controller.send(:current_user)
      payload[:user_id] = user.id
      payload[:user_email] = user.email
    end

    payload
  end

  # Keep original Rails logger for other logs
  config.lograge.keep_original_rails_log = false

  # Ignore certain paths (health checks, assets)
  config.lograge.ignore_actions = [
    'HealthController#live',
    'HealthController#ready',
    'HealthController#details'
  ]

  # Also ignore asset requests
  config.lograge.ignore_custom = lambda do |event|
    event.payload[:path]&.start_with?('/assets/', '/packs/')
  end
end

# Helper method to filter sensitive parameters
def filter_sensitive_params(params)
  sensitive_keys = %w[
    password password_confirmation
    token api_key secret
    credit_card card_number cvv
    authenticity_token
  ]

  params.to_h.except(*sensitive_keys).reject do |key, _value|
    sensitive_keys.any? { |sensitive| key.to_s.include?(sensitive) }
  end
rescue StandardError
  {}
end
