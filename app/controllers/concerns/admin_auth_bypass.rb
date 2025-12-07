# frozen_string_literal: true

# AdminAuthBypass
# Allows bypassing admin authentication in development and e2e environments.
#
# Usage: Set BYPASS_ADMIN_AUTH=true in dev or e2e environment
#
# SECURITY: This bypass is ONLY allowed in development and e2e environments.
# It will be ignored in production, staging, and any other environment.
module AdminAuthBypass
  extend ActiveSupport::Concern

  ALLOWED_ENVIRONMENTS = %w[development e2e test].freeze

  included do
    # Override Devise's authenticate_user! if bypass is enabled
    prepend_before_action :check_admin_auth_bypass
  end

  private

  def bypass_admin_auth?
    return false unless ALLOWED_ENVIRONMENTS.include?(Rails.env)
    ENV['BYPASS_ADMIN_AUTH'] == 'true'
  end

  def check_admin_auth_bypass
    if bypass_admin_auth?
      # Create a mock admin user session if needed
      sign_in_bypass_user if current_user.nil?
    end
  end

  def sign_in_bypass_user
    # Find or create a bypass admin user for the current website
    bypass_user = find_or_create_bypass_user
    sign_in(bypass_user) if bypass_user
  end

  def find_or_create_bypass_user
    # Try to find an existing admin user for the current website
    website = respond_to?(:current_website) ? current_website : Pwb::Current.website
    return nil unless website

    # First try to find a user with admin membership for this website
    existing_admin = Pwb::UserMembership.active.admins.for_website(website).first&.user
    return existing_admin if existing_admin

    # Fall back to legacy admin flag check
    legacy_admin = Pwb::User.find_by(website_id: website.id, admin: true)
    return legacy_admin if legacy_admin

    # Create a bypass admin user if none exists
    user = Pwb::User.find_or_create_by!(email: "bypass-admin@#{website.subdomain || 'default'}.test") do |u|
      u.password = 'bypass_password_123'
      u.password_confirmation = 'bypass_password_123'
      u.website_id = website.id
      u.admin = true
    end

    # Ensure user has admin membership for this website
    Pwb::UserMembership.find_or_create_by!(user: user, website: website) do |m|
      m.role = 'admin'
      m.active = true
    end

    user
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "[AdminAuthBypass] Could not create bypass user: #{e.message}"
    nil
  end
end
