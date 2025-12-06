# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Content.
  # Inherits all functionality from Pwb::Content but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Content for console work or cross-tenant operations.
  #
  class Content < Pwb::Content
    include RequiresTenant
    acts_as_tenant :website
  end
end
