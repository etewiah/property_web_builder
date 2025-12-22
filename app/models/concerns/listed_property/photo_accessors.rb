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
        Rails.application.routes.url_helpers.rails_blob_path(first_photo.image, only_path: true)
      else
        ""
      end
    end
  end
end
