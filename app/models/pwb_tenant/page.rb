# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Page.
  # Inherits all functionality from Pwb::Page but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Page for console work or cross-tenant operations.
  #
  class Page < Pwb::Page
    acts_as_tenant :website
  end
end
