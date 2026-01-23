# frozen_string_literal: true

require 'mini_magick'

module Pwb
  # Service for generating responsive image variants from seed images
  #
  # Usage:
  #   variants = Pwb::SeedImageVariants.generate_from_file('/path/to/image.jpg')
  #   # => { 'thumb' => <binary>, 'small' => <binary>, ... }
  #
  #   variants = Pwb::SeedImageVariants.generate_from_url('https://example.com/image.jpg')
  #   # => { 'thumb' => <binary>, 'small' => <binary>, ... }
  #
  module SeedImageVariants
    # Variant dimensions matching the API response format
    # Uses resize_to_limit to maintain aspect ratio
    VARIANT_SIZES = {
      'thumb' => [150, 100],
      'small' => [300, 200],
      'medium' => [600, 400],
      'large' => [1200, 800]
    }.freeze

    # Supported output formats
    FORMATS = %w[jpg webp].freeze

    class << self
      # Generate all variants from a local file
      #
      # @param file_path [String] Path to the source image
      # @return [Hash] Hash of variant_name => { format => binary_data }
      def generate_from_file(file_path)
        raise ArgumentError, "File not found: #{file_path}" unless File.exist?(file_path)

        generate_variants(File.binread(file_path))
      end

      # Generate all variants from a URL
      #
      # @param url [String] URL of the source image
      # @return [Hash] Hash of variant_name => { format => binary_data }
      def generate_from_url(url)
        require 'net/http'
        require 'uri'

        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 10
        http.read_timeout = 30

        # Handle SSL verification (macOS OpenSSL 3.6+ compatibility)
        if http.use_ssl?
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.verify_callback = ->(_preverify_ok, _store_ctx) { true }
        end

        response = http.get(uri.request_uri)
        raise "Failed to download image: HTTP #{response.code}" unless response.code.to_i == 200

        generate_variants(response.body)
      end

      # Generate all variants from binary image data
      #
      # @param image_data [String] Binary image data
      # @return [Hash] Hash of variant_name => { format => binary_data }
      def generate_variants(image_data)
        results = {}

        VARIANT_SIZES.each do |name, dimensions|
          results[name] = {}

          FORMATS.each do |format|
            results[name][format] = resize_image(image_data, dimensions, format)
          end
        end

        results
      end

      # Build variant key for R2 storage
      # Follows naming convention: {path}/{basename}_{variant}.{ext}
      #
      # @param original_key [String] Original R2 key (e.g., 'seeds/villa_ocean.jpg')
      # @param variant_name [String] Variant name (e.g., 'thumb', 'small')
      # @param format [String] Output format ('jpg' or 'webp')
      # @return [String] Variant key (e.g., 'seeds/villa_ocean_thumb.jpg')
      def variant_key(original_key, variant_name, format)
        dir = File.dirname(original_key)
        ext = File.extname(original_key)
        basename = File.basename(original_key, ext)

        "#{dir}/#{basename}_#{variant_name}.#{format}"
      end

      # Build all variant keys for a given original key
      #
      # @param original_key [String] Original R2 key
      # @return [Array<Hash>] Array of { key:, variant:, format: }
      def all_variant_keys(original_key)
        keys = []

        VARIANT_SIZES.keys.each do |variant_name|
          FORMATS.each do |format|
            keys << {
              key: variant_key(original_key, variant_name, format),
              variant: variant_name,
              format: format
            }
          end
        end

        keys
      end

      private

      # Resize image to specified dimensions using MiniMagick
      #
      # @param image_data [String] Binary image data
      # @param dimensions [Array<Integer>] [width, height]
      # @param format [String] Output format ('jpg' or 'webp')
      # @return [String] Binary data of resized image
      def resize_image(image_data, dimensions, format)
        width, height = dimensions

        # Create temp file for MiniMagick
        image = MiniMagick::Image.read(image_data)

        # Resize to fit within dimensions (resize_to_limit behavior)
        image.resize "#{width}x#{height}>"

        # Set output format
        image.format format

        # Quality settings
        if format == 'jpg'
          image.quality 85
        elsif format == 'webp'
          image.quality 80
        end

        # Return binary data
        image.to_blob
      ensure
        image&.destroy!
      end
    end
  end
end
