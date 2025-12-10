# frozen_string_literal: true

module Pwb
  class ContentPhoto < ApplicationRecord
    include ExternalImageSupport

    has_one_attached :image, dependent: :purge_later
    belongs_to :content, optional: true
    # I use block_key col to indicate if there is a fragment block associated
    # with this photo

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

    def image_filename
      # For external URLs, extract filename from URL
      return File.basename(URI.parse(external_url).path) if external?
      read_attribute(:image)
    end

    def as_json(options = nil)
      super({only: [
               "description", "folder", "sort_order", "block_key", "external_url"
             ],
             methods: ["optimized_image_url", "image_filename"]
             }.merge(options || {}))
    end

    # Check if website is in external image mode
    def external_image_mode?
      content&.website&.external_image_mode || false
    end
  end
end
