# frozen_string_literal: true

# Concern for models that support external image URLs.
# When a website has external_image_mode enabled, images can be stored
# as external URLs instead of being uploaded to ActiveStorage.
#
# This allows tenants to reference images hosted elsewhere (e.g., CDN,
# existing media servers) without duplicating storage.
#
module ExternalImageSupport
  extend ActiveSupport::Concern

  included do
    # Validate external_url format when present
    validates :external_url, format: {
      with: /\A(https?:\/\/)[\w\-._~:\/?#\[\]@!$&'()*+,;=%]+\z/i,
      message: "must be a valid HTTP or HTTPS URL"
    }, allow_blank: true
  end

  # Returns true if this photo uses an external URL instead of ActiveStorage
  def external?
    external_url.present?
  end

  # Returns the image URL - either external URL or ActiveStorage URL
  # @param variant_options [Hash] Options for ActiveStorage variant (ignored for external URLs)
  # @return [String, nil] The image URL or nil if no image
  def image_url(variant_options: nil)
    if external?
      external_url
    elsif image.attached?
      active_storage_url(variant_options: variant_options)
    end
  end

  # Returns a thumbnail URL for the image
  # @param size [Array<Integer, Integer>] Thumbnail dimensions [width, height]
  # @return [String, nil] The thumbnail URL or nil if no image
  def thumbnail_url(size: [200, 200])
    if external?
      # For external URLs, we can't generate variants, so return the original
      # A future enhancement could use an image proxy service for resizing
      external_url
    elsif image.attached? && image.variable?
      Rails.application.routes.url_helpers.rails_representation_path(
        image.variant(resize_to_limit: size),
        only_path: true
      )
    elsif image.attached?
      Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
    end
  end

  # Check if this photo has any image (external or uploaded)
  def has_image?
    external? || image.attached?
  end

  private

  def active_storage_url(variant_options: nil)
    return nil unless image.attached?

    if variant_options && image.variable?
      Rails.application.routes.url_helpers.rails_representation_path(
        image.variant(variant_options),
        only_path: true
      )
    else
      Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
    end
  end
end
