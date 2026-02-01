# frozen_string_literal: true

# Multi-tenancy related errors
#
# These errors are raised when tenant (website) context is missing or invalid.
#

# Raised when a required website/tenant context is not present
class TenantNotFoundError < ApplicationError
  def initialize(message = nil, details: {})
    super(
      message || "Website context not found",
      code: "TENANT_NOT_FOUND",
      details: details,
      http_status: :bad_request
    )
  end
end

# Raised when accessing a resource that doesn't belong to the current tenant
class TenantMismatchError < ApplicationError
  def initialize(message = nil, details: {})
    super(
      message || "Resource does not belong to this website",
      code: "TENANT_MISMATCH",
      details: details,
      http_status: :forbidden
    )
  end
end

# Raised when tenant context is required but missing
# (Replaces TenantContextError from site_admin_indexable.rb for consistency)
class TenantContextRequiredError < ApplicationError
  def initialize(message = nil, details: {})
    super(
      message || "Website context required for this operation",
      code: "TENANT_CONTEXT_REQUIRED",
      details: details,
      http_status: :bad_request
    )
  end
end
