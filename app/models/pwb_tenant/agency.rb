# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Agency.
  # Inherits all functionality from Pwb::Agency but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Agency for console work or cross-tenant operations.
  #
  class Agency < Pwb::Agency
    acts_as_tenant :website
  end
end
