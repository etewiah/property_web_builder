# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_content_photos
# Database name: primary
#
#  id           :integer          not null, primary key
#  block_key    :string
#  description  :string
#  external_url :string
#  file_size    :integer
#  folder       :string
#  image        :string
#  sort_order   :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  content_id   :integer
#
# Indexes
#
#  index_pwb_content_photos_on_content_id  (content_id)
#
module Pwb
  class ContentPhoto < ApplicationRecord
    include ExternalImageSupport

    has_one_attached :image, dependent: :purge_later
    belongs_to :content, optional: true
    # I use block_key col to indicate if there is a fragment block associated
    # with this photo

    # Returns optimized image URL
    #
    # Returns a direct CDN URL when CDN_IMAGES_URL is configured.
    # Falls back to external URL if in external image mode.
    #
    # @return [String, nil] The optimized image URL
    def optimized_image_url
      # Use external URL if available
      return external_url if external?

      return nil unless image.attached?

      # Use variants for optimization when possible
      # Returns direct CDN URL (respects CDN_IMAGES_URL/R2_PUBLIC_URL)
      if image.variable?
        image.variant(resize_to_limit: [800, 600]).processed.url
      else
        image.url
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to generate optimized URL for ContentPhoto##{id}: #{e.message}"
      image.attached? ? image.url : nil
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
