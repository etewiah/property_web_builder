# frozen_string_literal: true

# Base class for all tenant-scoped models
#
# Models in the PwbTenant:: namespace are automatically scoped to the current
# website (tenant). This is enforced by acts_as_tenant.
#
# Usage:
#   class PwbTenant::Contact < PwbTenant::ApplicationRecord
#     # Automatically scoped to current website
#   end
#
# Queries are automatically filtered:
#   PwbTenant::Contact.all  # => Only returns contacts for current tenant
#
# For cross-tenant access (super admin), use:
#   ActsAsTenant.without_tenant { PwbTenant::Contact.all }
#
module PwbTenant
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    # Use same table prefix as Pwb:: models - no database changes needed
    self.table_name_prefix = 'pwb_'

    # Automatic tenant scoping for ALL PwbTenant models
    # The tenant is Pwb::Website
    acts_as_tenant :website, class_name: 'Pwb::Website'

    # Ensure website is always present
    validates :website, presence: true
  end
end
