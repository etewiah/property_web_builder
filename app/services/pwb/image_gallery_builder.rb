# frozen_string_literal: true

module Pwb
  # ImageGalleryBuilder
  #
  # Service class for building a unified image gallery from multiple photo sources.
  # Aggregates content photos, website photos, and property photos into a single
  # collection with consistent structure.
  #
  # Usage:
  #   builder = Pwb::ImageGalleryBuilder.new(website, url_helper: self)
  #   images = builder.build
  #
  # Each image hash includes:
  #   - id: String (e.g., "content_123", "website_456", "prop_789")
  #   - type: String ('content', 'website', 'property')
  #   - url: String (full URL to image)
  #   - thumb_url: String (thumbnail URL)
  #   - filename: String
  #   - description: String or nil
  #
  class ImageGalleryBuilder
    DEFAULT_LIMITS = {
      content: 50,
      website: 20,
      property: 30
    }.freeze

    THUMBNAIL_SIZE = [150, 150].freeze

    # @param website [Pwb::Website] The website to fetch images for
    # @param url_helper [Object] An object that responds to url_for (typically a controller)
    # @param limits [Hash] Optional custom limits per photo type
    def initialize(website, url_helper:, limits: {})
      @website = website
      @url_helper = url_helper
      @limits = DEFAULT_LIMITS.merge(limits)
    end

    # Build the complete image gallery
    # @return [Array<Hash>] Array of image hashes
    def build
      images = []
      images.concat(content_photos)
      images.concat(website_photos)
      images.concat(property_photos)
      images
    end

    # Fetch only content photos
    # @return [Array<Hash>]
    def content_photos
      photos = ContentPhoto.joins(:content)
                           .where(pwb_contents: { website_id: @website&.id })
                           .order(created_at: :desc)
                           .limit(@limits[:content])

      build_photo_hashes(photos, type: 'content', id_prefix: 'content') do |photo|
        photo.description
      end
    end

    # Fetch only website photos
    # @return [Array<Hash>]
    def website_photos
      photos = @website&.website_photos&.order(created_at: :desc)&.limit(@limits[:website]) || []

      build_photo_hashes(photos, type: 'website', id_prefix: 'website') do |photo|
        photo.try(:description)
      end
    end

    # Fetch only property photos
    # @return [Array<Hash>]
    def property_photos
      photos = PropPhoto.joins(:realty_asset)
                        .where(pwb_realty_assets: { website_id: @website&.id })
                        .order(created_at: :desc)
                        .limit(@limits[:property])

      build_photo_hashes(photos, type: 'property', id_prefix: 'prop') do |photo|
        # Use reference as fallback since title lives on listings, not assets
        photo.realty_asset&.reference
      end
    end

    private

    # Build consistent hash structures for a collection of photos
    #
    # @param photos [Enumerable] Collection of photo objects
    # @param type [String] The type label for these photos
    # @param id_prefix [String] Prefix for the id field
    # @yield [photo] Block to extract description for each photo
    # @return [Array<Hash>]
    def build_photo_hashes(photos, type:, id_prefix:)
      photos.filter_map do |photo|
        next unless photo.image.attached?

        build_single_photo_hash(photo, type: type, id_prefix: id_prefix) do
          yield(photo) if block_given?
        end
      end
    end

    # Build a hash for a single photo
    #
    # @param photo [Object] A photo object with an attached image
    # @param type [String] The type label
    # @param id_prefix [String] Prefix for the id
    # @yield Block to get description
    # @return [Hash, nil] The photo hash or nil on error
    def build_single_photo_hash(photo, type:, id_prefix:)
      {
        id: "#{id_prefix}_#{photo.id}",
        type: type,
        url: @url_helper.url_for(photo.image),
        thumb_url: thumbnail_url(photo.image),
        filename: photo.image.filename.to_s,
        description: block_given? ? yield : nil
      }
    rescue StandardError => e
      Rails.logger.warn "Error processing #{type} photo #{photo.id}: #{e.message}"
      nil
    end

    # Generate a thumbnail URL for an image
    #
    # @param image [ActiveStorage::Attached] The attached image
    # @return [String] URL to the thumbnail or original image
    def thumbnail_url(image)
      return @url_helper.url_for(image) unless image.variable?

      @url_helper.url_for(image.variant(resize_to_limit: THUMBNAIL_SIZE))
    rescue StandardError => e
      Rails.logger.warn "Error generating thumbnail: #{e.message}"
      @url_helper.url_for(image)
    end
  end
end
