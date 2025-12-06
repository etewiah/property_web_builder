# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Prop.
  # Inherits all functionality from Pwb::Prop but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Prop for console work or cross-tenant operations.
  #
  class Prop < Pwb::Prop
    include RequiresTenant
    acts_as_tenant :website
  end
end
