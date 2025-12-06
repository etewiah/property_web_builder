# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of PagePart.
  # Inherits all functionality from Pwb::PagePart but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::PagePart for console work or cross-tenant operations.
  #
  class PagePart < Pwb::PagePart
    include RequiresTenant
    acts_as_tenant :website
  end
end
