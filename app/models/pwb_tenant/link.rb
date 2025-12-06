# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Link.
  # Inherits all functionality from Pwb::Link but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Link for console work or cross-tenant operations.
  #
  class Link < Pwb::Link
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
