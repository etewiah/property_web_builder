# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of WebsitePhoto.
  # Inherits all functionality from Pwb::WebsitePhoto but automatically
  # scopes queries to the current tenant via acts_as_tenant.
  #
  # Use this in web requests where tenant isolation is required.
  # Use Pwb::WebsitePhoto for console work or cross-tenant operations.
  #
  class WebsitePhoto < Pwb::WebsitePhoto
    include RequiresTenant
    acts_as_tenant :website, class_name: 'Pwb::Website'
  end
end
