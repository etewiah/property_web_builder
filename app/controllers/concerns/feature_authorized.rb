# frozen_string_literal: true

# FeatureAuthorized
#
# Provides feature-based access control for controllers.
# Include this concern in any controller that needs to gate access
# based on plan features.
#
# Usage:
#   class SiteAdmin::AnalyticsController < SiteAdminController
#     include FeatureAuthorized
#
#     before_action { require_feature('analytics') }
#     # or
#     before_action :require_analytics_feature
#
#     private
#
#     def require_analytics_feature
#       require_feature('analytics')
#     end
#   end
#
module FeatureAuthorized
  extend ActiveSupport::Concern

  # Custom error raised when a feature is not available on the current plan
  class FeatureNotAuthorized < StandardError
    attr_reader :feature_key

    def initialize(feature_key, message = nil)
      @feature_key = feature_key
      super(message || "Feature '#{feature_key}' is not included in your plan")
    end
  end

  included do
    rescue_from FeatureNotAuthorized, with: :handle_feature_not_authorized
    helper_method :feature_available?
  end

  private

  # Require a specific feature to access this action
  #
  # @param feature_key [String, Symbol] The feature key to check
  # @raise [FeatureNotAuthorized] if the feature is not available
  #
  def require_feature(feature_key)
    return if current_website&.has_feature?(feature_key)

    raise FeatureNotAuthorized.new(
      feature_key,
      "This feature is not included in your current plan. Please upgrade to access #{feature_key.to_s.humanize}."
    )
  end

  # Check if a feature is available without raising an error
  #
  # @param feature_key [String, Symbol] The feature key to check
  # @return [Boolean]
  #
  def feature_available?(feature_key)
    current_website&.has_feature?(feature_key) || false
  end

  # Handler for FeatureNotAuthorized errors
  # Redirects to billing page with an upgrade message
  #
  def handle_feature_not_authorized(exception)
    respond_to do |format|
      format.html do
        flash[:alert] = exception.message
        redirect_to site_admin_billing_path
      end
      format.json do
        render json: {
          error: 'feature_not_authorized',
          message: exception.message,
          feature: exception.feature_key
        }, status: :forbidden
      end
    end
  end

  # Helper to define feature requirements declaratively
  #
  # @example
  #   class SomeController < SiteAdminController
  #     include FeatureAuthorized
  #     require_feature_for :analytics, only: [:show, :index]
  #   end
  #
  class_methods do
    def require_feature_for(feature_key, **options)
      before_action(**options) { require_feature(feature_key) }
    end
  end
end
