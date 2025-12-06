# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of RealtyAsset.
  # Inherits all functionality from Pwb::RealtyAsset but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::RealtyAsset for console work or cross-tenant operations.
  #
  class RealtyAsset < Pwb::RealtyAsset
    acts_as_tenant :website
  end
end
