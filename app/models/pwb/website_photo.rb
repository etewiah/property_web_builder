# frozen_string_literal: true

module Pwb
  # WebsitePhoto stores branding images for websites.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::WebsitePhoto for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class WebsitePhoto < ApplicationRecord
    include ExternalImageSupport

    belongs_to :website, optional: true
    has_one_attached :image, dependent: :purge_later

    def optimized_image_url
      # Use external URL if available
      return external_url if external?

      return nil unless image.attached?

      # Use variants for optimization when possible
      if image.variable?
        Rails.application.routes.url_helpers.rails_representation_path(
          image.variant(resize_to_limit: [800, 600]),
          only_path: true
        )
      else
        Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
      end
    end

    # Check if website is in external image mode
    def external_image_mode?
      website&.external_image_mode || false
    end
  end
end
