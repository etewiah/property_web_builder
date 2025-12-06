# frozen_string_literal: true

module PwbTenant
  # Concern that enforces tenant requirement for PwbTenant:: models.
  #
  # When included, raises an error if a query is attempted without
  # a current tenant set. This ensures PwbTenant:: models are always
  # properly scoped.
  #
  # Use Pwb:: models for cross-tenant operations or console work.
  #
  module RequiresTenant
    extend ActiveSupport::Concern

    included do
      # Add a default scope that checks for tenant presence
      default_scope do
        if ActsAsTenant.current_tenant.nil? && !ActsAsTenant.unscoped?
          raise ActsAsTenant::Errors::NoTenantSet,
                "#{name} requires a tenant to be set. Use Pwb::#{name.demodulize} for cross-tenant queries, " \
                "or set a tenant with ActsAsTenant.with_tenant(website) { ... }"
        end
        all
      end
    end
  end
end
