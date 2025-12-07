# frozen_string_literal: true

module Constraints
  # Route constraint that checks if the user is authorized for tenant admin access.
  # Uses the same logic as TenantAdminController - checks TENANT_ADMIN_EMAILS env var.
  #
  # Usage in routes.rb:
  #   constraints Constraints::TenantAdminConstraint.new do
  #     mount SomeEngine => "/admin_path"
  #   end
  #
  class TenantAdminConstraint
    def matches?(request)
      return true if bypass_auth?

      user = request.env['warden']&.user
      return false unless user

      tenant_admin_allowed?(user)
    end

    private

    def bypass_auth?
      return false if Rails.env.production?

      ENV.fetch('BYPASS_ADMIN_AUTH', 'false').downcase == 'true'
    end

    def tenant_admin_allowed?(user)
      allowed_emails = ENV.fetch('TENANT_ADMIN_EMAILS', '').split(',').map(&:strip).map(&:downcase)
      return false if allowed_emails.empty?

      allowed_emails.include?(user.email.downcase)
    end
  end
end
