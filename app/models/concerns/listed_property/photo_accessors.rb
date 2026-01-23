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
    # Supports both external URLs and Active Storage attachments
    # Uses direct CDN URLs when available via ActiveStorage's url method
    # @return [String] the image URL or empty string if no image
    def primary_image_url
      first_photo = ordered_photo(1)
      return "" unless first_photo&.has_image?

      if first_photo.external?
        first_photo.external_url
      elsif first_photo.image.attached?
        first_photo.image.url
      else
        ""
      end
    rescue StandardError => e
      Rails.logger.warn("Failed to generate primary image URL: #{e.message}")
      ""
    end
  end
end

