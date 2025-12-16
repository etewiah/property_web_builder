# frozen_string_literal: true

# SiteAdminOnboarding
#
# Include this concern in SiteAdminController to automatically redirect
# newly provisioned users to the onboarding wizard.
#
# Usage:
#   class SiteAdminController < ActionController::Base
#     include SiteAdminOnboarding
#   end
#
# Skip onboarding redirect for specific actions:
#   skip_before_action :redirect_to_onboarding_if_needed, only: [:some_action]
#
module SiteAdminOnboarding
  extend ActiveSupport::Concern

  included do
    before_action :redirect_to_onboarding_if_needed
  end

  private

  # Redirect user to onboarding wizard if they haven't completed it
  # Skips redirect if:
  # - User is not signed in
  # - User has already completed onboarding
  # - Current request is already to the onboarding controller
  # - Request is for API/JSON
  #
  def redirect_to_onboarding_if_needed
    return unless should_redirect_to_onboarding?

    redirect_to site_admin_onboarding_path
  end

  def should_redirect_to_onboarding?
    # Skip if not signed in
    return false unless current_user

    # Skip if already on onboarding pages
    return false if onboarding_controller?

    # Skip for API/JSON requests
    return false if request.format.json?

    # Skip if onboarding is completed
    return false if onboarding_completed?

    # Skip if user is not in an onboarding-eligible state
    return false unless user_needs_onboarding?

    true
  end

  def onboarding_controller?
    controller_name == 'onboarding'
  end

  def onboarding_completed?
    current_user.site_admin_onboarding_completed_at.present?
  end

  def user_needs_onboarding?
    # User needs onboarding if:
    # 1. They have never completed site admin onboarding
    # 2. They are a new owner/admin for this website
    # 3. The website was recently provisioned

    return false unless current_website

    # Check if this is a newly provisioned website (provisioned within last 30 days)
    # and user hasn't completed onboarding
    website_is_new = current_website.created_at > 30.days.ago

    # Check if user has owner/admin role
    user_is_admin = current_user.admin_for?(current_website)

    # Only show onboarding to admins of new websites who haven't completed it
    website_is_new && user_is_admin && !onboarding_completed?
  end

  # Helper to check if current user has completed onboarding
  # Can be used in views to conditionally show onboarding prompts
  def onboarding_complete?
    onboarding_completed?
  end
  helper_method :onboarding_complete? if respond_to?(:helper_method)

  # Get onboarding progress percentage
  def onboarding_progress
    return 100 if onboarding_completed?
    return 0 unless current_user

    current_user.onboarding_progress_percentage
  end
  helper_method :onboarding_progress if respond_to?(:helper_method)
end
