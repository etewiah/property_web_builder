# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Message.
  # Inherits all functionality from Pwb::Message but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::Message for console work or cross-tenant operations.
  #
  class Message < Pwb::Message
    acts_as_tenant :website
  end
end
