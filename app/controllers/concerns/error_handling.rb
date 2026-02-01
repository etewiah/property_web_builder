# frozen_string_literal: true

# ErrorHandling Concern
#
# Provides structured error logging and rescue handlers for controllers.
# Integrates with StructuredLogger for consistent JSON logging and Sentry.
#
# Include in controllers that need consistent error handling.
#
# Usage:
#   class MyController < ApplicationController
#     include ErrorHandling
#   end
#
# The concern provides:
# - Structured logging via StructuredLogger (JSON format, Sentry integration)
# - Consistent API error responses
# - Rescue handlers for common error types
# - Helper methods for logging caught exceptions
#
module ErrorHandling
  extend ActiveSupport::Concern

  included do
    # Rescue application errors with proper logging and response
    rescue_from ::ApplicationError do |error|
      log_application_error(error)
      render_error_response(error)
    end

    # Rescue external service errors
    rescue_from ::ExternalServiceError do |error|
      log_external_service_error(error)
      render_error_response(error)
    end

    # Rescue tenant errors
    rescue_from ::TenantNotFoundError, ::TenantMismatchError, ::TenantContextRequiredError do |error|
      log_application_error(error, level: :warn)
      render_error_response(error)
    end

    # Rescue subscription errors
    rescue_from ::SubscriptionError, ::FeatureNotAvailableError do |error|
      log_application_error(error, level: :info)
      render_error_response(error)
    end
  end

  private

  # Log an ApplicationError with structured context
  #
  # @param error [ApplicationError] The error to log
  # @param level [Symbol] Log level (:info, :warn, :error)
  def log_application_error(error, level: :warn)
    context = error_base_context.merge(error.respond_to?(:to_log_hash) ? error.to_log_hash : {})

    case level
    when :info
      StructuredLogger.info("[#{error.class.name}] #{error.message}", **context)
    when :warn
      StructuredLogger.warn("[#{error.class.name}] #{error.message}", **context)
    else
      StructuredLogger.error("[#{error.class.name}] #{error.message}", **context)
    end
  end

  # Log an external service error with full context
  #
  # @param error [ExternalServiceError] The error to log
  def log_external_service_error(error)
    context = error_base_context.merge(
      service_name: error.service_name,
      original_error: error.original_error&.message
    ).compact

    StructuredLogger.error("[ExternalService] #{error.message}", **context)
  end

  # Log a rescued exception with full context
  # Use this in rescue blocks for proper error tracking
  #
  # @param error [Exception] The rescued exception
  # @param context_message [String] Description of what was being attempted
  # @param extra_context [Hash] Additional context to include
  #
  # @example
  #   begin
  #     process_payment
  #   rescue Stripe::CardError => e
  #     log_rescued_exception(e, context_message: "Processing payment", order_id: order.id)
  #     # handle gracefully...
  #   end
  def log_rescued_exception(error, context_message: nil, **extra_context)
    context = error_base_context.merge(extra_context)
    message = context_message || "Rescued exception"

    StructuredLogger.exception(error, "[#{controller_name}##{action_name}] #{message}", **context)
  end

  # Log an error without raising (for graceful degradation)
  # Use when you want to catch an error, log it, but continue execution
  #
  # @param error [Exception] The error that occurred
  # @param fallback_value [Object] What to return instead
  # @param context_message [String] What was being attempted
  #
  # @example
  #   def fetch_optional_data
  #     SomeService.call
  #   rescue SomeError => e
  #     log_and_continue(e, fallback_value: [], context_message: "Fetching optional data")
  #   end
  def log_and_continue(error, fallback_value: nil, context_message: nil, **extra_context)
    log_rescued_exception(error, context_message: context_message, **extra_context)
    fallback_value
  end

  # Base context included in all error logs
  def error_base_context
    {
      controller: controller_name,
      action: action_name,
      path: request.path,
      method: request.method,
      user_id: respond_to?(:current_user, true) ? current_user&.id : nil,
      website_id: respond_to?(:current_website, true) ? current_website&.id : nil
    }.compact
  end

  # Render a JSON error response for ApplicationError subclasses
  def render_error_response(error)
    status = error.respond_to?(:http_status) ? error.http_status : :internal_server_error

    if request.format.json? || request.content_type&.include?('json')
      render json: error_to_json(error), status: status
    else
      # For HTML requests, set flash and redirect or render error page
      flash[:error] = error.message
      if request.referer.present?
        redirect_back(fallback_location: root_path)
      else
        render plain: error.message, status: status
      end
    end
  end

  # Convert error to JSON response format
  def error_to_json(error)
    response = { success: false }

    if error.respond_to?(:to_api_response)
      response.merge(error.to_api_response)
    else
      response.merge(
        error: error.class.name.demodulize.underscore.upcase,
        message: error.message
      )
    end
  end
end
