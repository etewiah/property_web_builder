# frozen_string_literal: true

module ApiPublic
  # Concern for generating responsive image variant URLs
  # Provides helper methods to include multiple image sizes in API responses
  # for properties, testimonials, and other image-bearing resources.
  module ImageVariants
    extend ActiveSupport::Concern

    # Standard variant dimensions for responsive images
    VARIANT_SIZES = {
      thumbnail: { resize_to_fill: [150, 100] },
      small: { resize_to_fill: [300, 200] },
      medium: { resize_to_fill: [600, 400] },
      large: { resize_to_fill: [1200, 800] }
    }.freeze

    # Variant name mappings for external URLs
    # Maps API variant names to the suffix used in R2 storage
    EXTERNAL_VARIANT_SUFFIXES = {
      thumbnail: 'thumb',
      small: 'small',
      medium: 'medium',
      large: 'large'
    }.freeze

    private

    # Generate variant URLs for an ActiveStorage attachment
    #
    # @param attachment [ActiveStorage::Attached::One] The image attachment
    # @return [Hash, nil] Hash of variant URLs or nil if not attached
    def image_variants_for(attachment)
      return nil unless attachment_valid?(attachment)

      variants = VARIANT_SIZES.transform_values do |transformations|
        variant_url(attachment, transformations)
      end

      variants[:original] = original_url(attachment)
      variants
    rescue StandardError => e
      Rails.logger.warn("[ImageVariants] Error generating variants: #{e.message}")
      nil
    end

    # Generate variant URLs for multiple attachments (e.g., property photos)
    #
    # @param attachments [ActiveStorage::Attached::Many] Collection of attachments
    # @param limit [Integer] Maximum number of images to process
    # @return [Array<Hash>] Array of image variant hashes
    def images_with_variants(attachments, limit: 10)
      return [] unless attachments.respond_to?(:each)

      attachments.first(limit).filter_map do |attachment|
        next unless attachment_valid?(attachment)

        {
          id: attachment.try(:id),
          alt: attachment.try(:alt_text) || attachment.try(:filename)&.to_s,
          variants: image_variants_for(attachment.try(:image) || attachment)
        }
      end
    rescue StandardError => e
      Rails.logger.warn("[ImageVariants] Error processing images: #{e.message}")
      []
    end

    # Check if an attachment is valid and processable
    def attachment_valid?(attachment)
      return false unless attachment

      if attachment.respond_to?(:attached?)
        attachment.attached?
      elsif attachment.respond_to?(:image) && attachment.image.respond_to?(:attached?)
        attachment.image.attached?
      else
        false
      end
    end

    # Generate URL for a specific variant
    def variant_url(attachment, transformations)
      Rails.application.routes.url_helpers.rails_representation_url(
        attachment.variant(transformations).processed,
        only_path: false,
        host: request.host_with_port,
        protocol: request.protocol
      )
    rescue StandardError
      nil
    end

    # Generate URL for the original image
    def original_url(attachment)
      Rails.application.routes.url_helpers.rails_blob_url(
        attachment,
        only_path: false,
        host: request.host_with_port,
        protocol: request.protocol
      )
    rescue StandardError
      nil
    end

    # Build variant URLs for external images stored in R2
    # Uses naming convention: {path}/{basename}_{variant}.{ext}
    #
    # @param external_url [String] The external URL of the original image
    # @return [Hash] Hash of variant URLs (both JPEG and WebP)
    #
    # Example:
    #   build_external_variants("https://seed-assets.example.com/seeds/villa_ocean.jpg")
    #   # => {
    #   #   thumbnail: "https://seed-assets.example.com/seeds/villa_ocean_thumb.jpg",
    #   #   thumbnail_webp: "https://seed-assets.example.com/seeds/villa_ocean_thumb.webp",
    #   #   small: "https://seed-assets.example.com/seeds/villa_ocean_small.jpg",
    #   #   ...
    #   # }
    def build_external_variants(external_url)
      return {} unless external_url.present?

      begin
        uri = URI.parse(external_url)
        ext = File.extname(uri.path)
        basename = File.basename(uri.path, ext)
        dir = File.dirname(uri.path)
        base = "#{uri.scheme}://#{uri.host}#{dir}/#{basename}"

        variants = {}

        EXTERNAL_VARIANT_SUFFIXES.each do |api_name, suffix|
          variants[api_name] = "#{base}_#{suffix}.jpg"
          variants[:"#{api_name}_webp"] = "#{base}_#{suffix}.webp"
        end

        variants
      rescue URI::InvalidURIError
        {}
      end
    end
  end
end
