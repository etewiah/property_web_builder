# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of FieldKey.
  # Inherits all functionality from Pwb::FieldKey but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::FieldKey for console work or cross-tenant operations.
  #
  class FieldKey < Pwb::FieldKey
    include RequiresTenant
    acts_as_tenant :website, foreign_key: 'pwb_website_id', class_name: 'Pwb::Website'
  end
end
