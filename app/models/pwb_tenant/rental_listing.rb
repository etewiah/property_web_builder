# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of RentalListing.
  # Inherits all functionality from Pwb::RentalListing but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::RentalListing for console work or cross-tenant operations.
  #
  class RentalListing < Pwb::RentalListing
    include RequiresTenant
    acts_as_tenant :website, through: :realty_asset, class_name: 'Pwb::Website'
  end
end
