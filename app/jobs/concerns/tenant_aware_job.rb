# frozen_string_literal: true

# TenantAwareJob - Concern for background jobs that need tenant context
#
# This concern ensures that ActsAsTenant.current_tenant is set when the job
# executes, allowing PwbTenant:: models to be safely queried.
#
# Usage:
#   class MyJob < ApplicationJob
#     include TenantAwareJob
#
#     def perform(website_id:, other_params:)
#       with_tenant do
#         # PwbTenant:: models are now scoped to the website
#         PwbTenant::Page.all  # Only returns pages for this website
#       end
#     end
#   end
#
# IMPORTANT:
#   - Jobs using this concern MUST pass website_id as a named parameter
#   - The website is loaded and tenant context is set via with_tenant block
#   - If website is not found, the job logs a warning and returns early
#
# For jobs that operate globally (across all tenants), do NOT include this concern.
# Instead, use the Pwb:: namespace directly with explicit website_id scoping.
#
module TenantAwareJob
  extend ActiveSupport::Concern

  included do
    # Store the website_id for tenant resolution
    attr_accessor :tenant_website_id
  end

  private

  # Execute a block within the context of a specific tenant
  #
  # @param website_id [Integer, nil] The website ID (uses @tenant_website_id if nil)
  # @yield Block to execute within tenant context
  # @return [Object, nil] The result of the block, or nil if tenant not found
  #
  def with_tenant(website_id = nil)
    website_id ||= @tenant_website_id

    unless website_id
      Rails.logger.warn "[#{self.class.name}] No website_id provided for tenant-aware job"
      return nil
    end

    website = Pwb::Website.find_by(id: website_id)

    unless website
      Rails.logger.warn "[#{self.class.name}] Website not found: #{website_id}"
      return nil
    end

    ActsAsTenant.with_tenant(website) do
      Pwb::Current.website = website
      yield
    end
  end

  # Set tenant context for the entire job execution
  # Call this at the start of perform if all logic needs tenant context
  #
  # @param website_id [Integer] The website ID
  # @return [Boolean] true if tenant was set, false otherwise
  #
  def set_tenant!(website_id)
    @tenant_website_id = website_id
    website = Pwb::Website.find_by(id: website_id)

    unless website
      Rails.logger.warn "[#{self.class.name}] Website not found: #{website_id}"
      return false
    end

    ActsAsTenant.current_tenant = website
    Pwb::Current.website = website
    true
  end

  # Clear tenant context (call in ensure block if using set_tenant!)
  def clear_tenant!
    ActsAsTenant.current_tenant = nil
    Pwb::Current.reset
    @tenant_website_id = nil
  end
end
