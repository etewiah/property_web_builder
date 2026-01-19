# frozen_string_literal: true

require_dependency "api_public/errors"

module ApiPublic
  module V1
    class BaseController < ActionController::Base
      include SubdomainTenant
      include ApiPublic::ResponseEnvelope
      include ApiPublic::ErrorHandler
      include ApiPublic::SparseFieldsets
      include ActiveStorage::SetCurrent

      skip_before_action :verify_authenticity_token

      # Set HTTP cache headers and conditional GET for all api_public endpoints
      before_action :set_api_public_cache_headers

      private

      def set_api_public_cache_headers
        expires_in 5.hours, public: true

        # Add Vary header for proper edge caching by tenant
        # This ensures CDN caches different responses per tenant/locale
        response.headers["Vary"] = "Accept-Language, X-Website-Slug"

        # Conditional GET: Use a generic last-modified time (can be overridden in child controllers)
        return unless respond_to?(:resource_last_modified, true)

        last_modified = resource_last_modified
        fresh_when(last_modified: last_modified) if last_modified
      end
    end
  end
end

