# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Feature.
  # Inherits all functionality from Pwb::Feature.
  #
  # Note: Feature doesn't have a website_id column - it inherits tenancy through
  # its parent Prop/RealtyAsset. No acts_as_tenant needed here, tenant scoping
  # happens through the parent association.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Feature for console work or cross-tenant operations.
  #
  class Feature < Pwb::Feature
    # No acts_as_tenant since Feature doesn't have website_id
    # Tenant scoping is handled through the parent RealtyAsset/Prop
  end
end
