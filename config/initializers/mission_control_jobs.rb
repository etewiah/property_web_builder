# frozen_string_literal: true

# Mission Control Jobs 1.0+ requires authentication configuration
# See: https://github.com/rails/mission_control-jobs#authentication

Rails.application.config.after_initialize do
  # Disable Mission Control's built-in HTTP Basic auth.
  # Authentication is handled by the TenantAdminConstraint route constraint
  # which uses the same logic as /tenant_admin (checks TENANT_ADMIN_EMAILS env var).
  MissionControl::Jobs.http_basic_auth_enabled = false
end
