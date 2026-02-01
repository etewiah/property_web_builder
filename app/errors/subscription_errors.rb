# frozen_string_literal: true

# Subscription and payment related errors
#
# These errors are raised during subscription management and payment processing.
#

# Base class for subscription errors
class SubscriptionError < ApplicationError
  attr_reader :subscription_id

  def initialize(message = nil, subscription_id: nil, details: {})
    @subscription_id = subscription_id
    details[:subscription_id] = subscription_id if subscription_id

    super(
      message || "Subscription error",
      code: "SUBSCRIPTION_ERROR",
      details: details,
      http_status: :payment_required
    )
  end
end

# Raised when a feature is not available on the current plan
class FeatureNotAvailableError < SubscriptionError
  attr_reader :feature_name, :required_plan

  def initialize(feature_name = nil, required_plan: nil, details: {})
    @feature_name = feature_name
    @required_plan = required_plan

    details[:feature] = feature_name if feature_name
    details[:required_plan] = required_plan if required_plan

    super(
      feature_name ? "Feature '#{feature_name}' is not available on your current plan" : "Feature not available",
      details: details
    )
    @code = "FEATURE_NOT_AVAILABLE"
    @http_status = :forbidden
  end
end

# Raised when subscription limit is exceeded
class SubscriptionLimitExceededError < SubscriptionError
  attr_reader :resource_type, :current_count, :limit

  def initialize(resource_type = nil, current_count: nil, limit: nil, details: {})
    @resource_type = resource_type
    @current_count = current_count
    @limit = limit

    details[:resource_type] = resource_type if resource_type
    details[:current_count] = current_count if current_count
    details[:limit] = limit if limit

    super(
      resource_type ? "#{resource_type.to_s.titleize} limit exceeded" : "Subscription limit exceeded",
      details: details
    )
    @code = "SUBSCRIPTION_LIMIT_EXCEEDED"
    @http_status = :forbidden
  end
end

# Raised when subscription is expired or inactive
class SubscriptionInactiveError < SubscriptionError
  attr_reader :status, :expired_at

  def initialize(message = nil, status: nil, expired_at: nil, details: {})
    @status = status
    @expired_at = expired_at

    details[:status] = status if status
    details[:expired_at] = expired_at&.iso8601 if expired_at

    super(
      message || "Your subscription is not active",
      details: details
    )
    @code = "SUBSCRIPTION_INACTIVE"
    @http_status = :payment_required
  end
end

# Raised when payment processing fails
class PaymentError < ApplicationError
  attr_reader :payment_provider, :decline_code

  def initialize(message = nil, payment_provider: nil, decline_code: nil, details: {})
    @payment_provider = payment_provider
    @decline_code = decline_code

    details[:provider] = payment_provider if payment_provider
    details[:decline_code] = decline_code if decline_code

    super(
      message || "Payment processing failed",
      code: "PAYMENT_ERROR",
      details: details,
      http_status: :payment_required
    )
  end
end
