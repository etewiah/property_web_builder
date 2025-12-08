# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of SaleListing.
  # Inherits all functionality from Pwb::SaleListing but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::SaleListing for console work or cross-tenant operations.
  #
  class SaleListing < Pwb::SaleListing
    include RequiresTenant
    acts_as_tenant :website, through: :realty_asset, class_name: 'Pwb::Website'
  end
end
