# frozen_string_literal: true

module ListedProperty
  # Provides photo access methods for ListedProperty
  # Handles ordered photo retrieval and primary image URL generation
  module PhotoAccessors
    extend ActiveSupport::Concern

    # Returns a photo by its display order (1-indexed)
    # @param number [Integer] the 1-based position of the photo
    # @return [Pwb::PropPhoto, nil] the photo at that position
    def ordered_photo(number)
      prop_photos[number - 1] if prop_photos.length >= number
    end

    # Returns the URL for the primary (first) image
    # @return [String] the image URL or empty string if no image
    def primary_image_url
      first_photo = ordered_photo(1)
      if prop_photos.any? && first_photo&.image&.attached?
        Rails.application.routes.url_helpers.rails_blob_url(
          first_photo.image,
          host: resolve_asset_host
        )
      else
        ""
      end
    end

    private

    def resolve_asset_host
      ENV.fetch('ASSET_HOST') do
        ENV.fetch('APP_HOST') do
          Rails.application.config.action_controller.asset_host ||
            Rails.application.routes.default_url_options[:host] ||
            'http://localhost:3000'
        end
      end
    end
  end
end

