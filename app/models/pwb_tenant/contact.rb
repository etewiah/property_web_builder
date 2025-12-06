# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Contact.
  # Inherits all functionality from Pwb::Contact but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Contact for console work or cross-tenant operations.
  #
  class Contact < Pwb::Contact
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
