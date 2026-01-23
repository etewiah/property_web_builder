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
    # Variant widths matching existing R2 uploads
    # Uses width-based naming convention: {basename}-{width}.webp
    # Heights are calculated to maintain 3:2 aspect ratio
    VARIANT_WIDTHS = {
      320 => [320, 213],
      640 => [640, 427],
      800 => [800, 533],
      1280 => [1280, 853]
    }.freeze

    # Mapping from semantic names to widths for API responses
    SEMANTIC_TO_WIDTH = {
      'thumbnail' => 320,
      'small' => 640,
      'medium' => 800,
      'large' => 1280
    }.freeze

    # Output format - WebP is the default (97%+ browser support)
    DEFAULT_FORMAT = 'webp'.freeze
    FORMATS = %w[webp].freeze

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
      # @return [Hash] Hash of width => { format => binary_data }
      def generate_variants(image_data)
        results = {}

        VARIANT_WIDTHS.each do |width, dimensions|
          results[width] = {}

          FORMATS.each do |format|
            results[width][format] = resize_image(image_data, dimensions, format)
          end
        end

        results
      end

      # Build variant key for R2 storage
      # Follows naming convention: {path}/{basename}-{width}.webp
      #
      # @param original_key [String] Original R2 key (e.g., 'seeds/villa_ocean.jpg')
      # @param width [Integer] Variant width (e.g., 320, 640, 800, 1280)
      # @param format [String] Output format (default: 'webp')
      # @return [String] Variant key (e.g., 'seeds/villa_ocean-640.webp')
      def variant_key(original_key, width, format = DEFAULT_FORMAT)
        dir = File.dirname(original_key)
        ext = File.extname(original_key)
        basename = File.basename(original_key, ext)

        "#{dir}/#{basename}-#{width}.#{format}"
      end

      # Build all variant keys for a given original key
      #
      # @param original_key [String] Original R2 key
      # @return [Array<Hash>] Array of { key:, width:, format: }
      def all_variant_keys(original_key)
        keys = []

        VARIANT_WIDTHS.keys.each do |width|
          FORMATS.each do |format|
            keys << {
              key: variant_key(original_key, width, format),
              width: width,
              format: format
            }
          end
        end

        keys
      end

      # Get the width for a semantic variant name
      #
      # @param semantic_name [String] e.g., 'thumbnail', 'small', 'medium', 'large'
      # @return [Integer] The corresponding width
      def width_for(semantic_name)
        SEMANTIC_TO_WIDTH[semantic_name.to_s]
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
