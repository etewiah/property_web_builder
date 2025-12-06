# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of ListedProperty.
  # Inherits all functionality from Pwb::ListedProperty but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::ListedProperty for console work or cross-tenant operations.
  #
  class ListedProperty < Pwb::ListedProperty
    include RequiresTenant
    acts_as_tenant :website
  end
end
