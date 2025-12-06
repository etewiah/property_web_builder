# frozen_string_literal: true

# Configuration for acts_as_tenant gem
# https://github.com/ErwinM/acts_as_tenant

ActsAsTenant.configure do |config|
  # Start permissive - don't require tenant to be set for all queries
  # This allows Pwb:: models to work without tenant context
  # and allows TenantAdminController to access cross-tenant data
  config.require_tenant = false
end
