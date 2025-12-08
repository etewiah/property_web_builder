# frozen_string_literal: true

# StructuredLogger provides a consistent interface for structured logging
# throughout the application. It outputs JSON-formatted logs with consistent
# fields for easy parsing by log aggregators (ELK, Datadog, etc.)
#
# Usage:
#   StructuredLogger.info('User signed in', user_id: user.id, provider: 'firebase')
#   StructuredLogger.error('Payment failed', error: e.message, order_id: order.id)
#   StructuredLogger.with_context(tenant_id: 123) do
#     StructuredLogger.info('Processing request')
#   end
#
class StructuredLogger
  LEVELS = %i[debug info warn error fatal].freeze

  class << self
    # Thread-local context for adding fields to all logs within a block
    def current_context
      Thread.current[:structured_logger_context] ||= {}
    end

    def current_context=(context)
      Thread.current[:structured_logger_context] = context
    end

    # Add context that will be included in all logs within the block
    def with_context(context = {})
      previous_context = current_context.dup
      self.current_context = current_context.merge(context)
      yield
    ensure
      self.current_context = previous_context
    end

    # Log methods for each level
    LEVELS.each do |level|
      define_method(level) do |message, **fields|
        log(level, message, **fields)
      end
    end

    # Main logging method
    def log(level, message, **fields)
      entry = build_log_entry(level, message, **fields)

      # Output as JSON
      case level
      when :debug
        Rails.logger.debug(entry.to_json)
      when :info
        Rails.logger.info(entry.to_json)
      when :warn
        Rails.logger.warn(entry.to_json)
      when :error, :fatal
        Rails.logger.error(entry.to_json)

        # Also send to Sentry for errors if configured
        send_to_sentry(level, message, fields) if defined?(Sentry) && Sentry.initialized?
      end
    end

    # Convenience method for logging exceptions
    def exception(error, message = nil, **fields)
      error_fields = {
        error_class: error.class.name,
        error_message: error.message,
        error_backtrace: error.backtrace&.first(15)
      }.merge(fields)

      log(:error, message || "Exception: #{error.class.name}", **error_fields)

      # Send to Sentry
      Sentry.capture_exception(error, extra: fields) if defined?(Sentry) && Sentry.initialized?
    end

    # Log a metric/event for analytics purposes
    def metric(name, value: 1, **tags)
      log(:info, "metric.#{name}", metric_name: name, metric_value: value, **tags)
    end

    # Performance logging
    def measure(name, **fields)
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = yield
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

      log(:info, "performance.#{name}", duration_ms: duration_ms, **fields)
      result
    end

    private

    def build_log_entry(level, message, **fields)
      entry = {
        timestamp: Time.current.iso8601(3),
        level: level.to_s.upcase,
        message: message,
        environment: Rails.env,
        application: 'property_web_builder'
      }

      # Add tenant context if available
      if defined?(Pwb::Current) && Pwb::Current.website
        entry[:tenant] = {
          id: Pwb::Current.website.id,
          subdomain: Pwb::Current.website.subdomain
        }
      end

      # Add request context if available
      if Thread.current[:request_id]
        entry[:request_id] = Thread.current[:request_id]
      end

      # Merge thread-local context
      entry.merge!(current_context)

      # Merge provided fields
      entry.merge!(fields)

      # Add caller info in development for debugging
      if Rails.env.development?
        caller_info = caller.find { |line| line.include?(Rails.root.to_s) && !line.include?('structured_logger') }
        entry[:caller] = caller_info&.sub(Rails.root.to_s + '/', '')
      end

      entry
    end

    def send_to_sentry(level, message, fields)
      return unless %i[error fatal].include?(level)

      Sentry.capture_message(message, level: level, extra: fields)
    end
  end
end

# Convenience module to include in classes
module StructuredLogging
  def structured_log
    StructuredLogger
  end

  # Add request context for controllers
  def set_logging_context
    Thread.current[:request_id] = request.request_id if respond_to?(:request)

    context = {}

    if defined?(Pwb::Current) && Pwb::Current.website
      context[:tenant_id] = Pwb::Current.website.id
      context[:tenant_subdomain] = Pwb::Current.website.subdomain
    end

    if respond_to?(:current_user, true) && current_user
      context[:user_id] = current_user.id
    end

    StructuredLogger.current_context = context
  end
end
