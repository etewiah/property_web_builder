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

    # Configure shards dynamically based on database.yml configuration
    # Only connect to shards that are actually configured
    shard_config = { default: { writing: :primary, reading: :primary } }
    
    # Add tenant_shard_1 only if configured in database.yml
    if ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'tenant_shard_1').present?
      shard_config[:shard_1] = { writing: :tenant_shard_1, reading: :tenant_shard_1 }
    end
    
    # Add demo_shard only if configured in database.yml
    if ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'demo_shard').present?
      shard_config[:demo] = { writing: :demo_shard, reading: :demo_shard }
    end
    
    connects_to shards: shard_config

    # Ensure website is always present
    validates :website, presence: true
  end
end
