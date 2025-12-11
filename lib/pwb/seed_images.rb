# frozen_string_literal: true

module Pwb
  # Helper module for accessing seed image URLs from R2
  #
  # This module provides methods to get external URLs for seed images,
  # allowing seeds to reference images without uploading to ActiveStorage.
  #
  # Usage in seeds:
  #   Pwb::SeedImages.property_url('villa_ocean')
  #   # => "https://pub-pwb-seed-images.r2.dev/seed-images/villa_ocean.jpg"
  #
  #   Pwb::SeedImages.content_url('hero_amsterdam_canal')
  #   # => "https://pub-pwb-seed-images.r2.dev/seed-images/hero_amsterdam_canal.jpg"
  #
  module SeedImages
    class << self
      # Get the full URL for a property image
      # @param image_key [String, Symbol] The image key (e.g., 'villa_ocean' or filename 'villa_ocean.jpg')
      # @return [String] The full URL to the image
      def property_url(image_key)
        build_url(:properties, image_key)
      end

      # Get the full URL for a content image (heroes, carousels, etc.)
      # @param image_key [String, Symbol] The image key
      # @return [String] The full URL to the image
      def content_url(image_key)
        build_url(:content, image_key)
      end

      # Get the full URL for a team member image
      # @param image_key [String, Symbol] The image key
      # @return [String] The full URL to the image
      def team_url(image_key)
        build_url(:team, image_key)
      end

      # Get any image URL by category and key
      # @param category [Symbol] Category (:properties, :content, :team)
      # @param image_key [String, Symbol] The image key
      # @return [String] The full URL to the image
      def url(category, image_key)
        build_url(category, image_key)
      end

      # Check if external seed images are enabled
      # @return [Boolean] true if SEED_IMAGES_BASE_URL is configured
      def enabled?
        ENV['SEED_IMAGES_BASE_URL'].present? || config['base_url'].present?
      end

      # Get the base URL for seed images
      # @return [String] The base URL
      def base_url
        config['base_url']
      end

      # Get the R2 bucket name from config
      # @return [String, nil] The bucket name
      def r2_bucket
        config['r2_bucket']
      end

      # Get the R2 account ID from config
      # @return [String, nil] The account ID
      def r2_account_id
        config['r2_account_id']
      end

      # Check if R2 upload configuration is complete
      # @return [Boolean] true if all required R2 vars are set
      def r2_upload_configured?
        ENV['R2_ACCESS_KEY_ID'].present? &&
          ENV['R2_SECRET_ACCESS_KEY'].present? &&
          ENV['R2_ACCOUNT_ID'].present? &&
          r2_bucket.present?
      end

      # Get R2 endpoint URL for API operations
      # @return [String, nil]
      def r2_endpoint
        return nil unless r2_account_id.present?

        "https://#{r2_account_id}.r2.cloudflarestorage.com"
      end

      # Get all configured property images
      # @return [Hash] Map of image keys to filenames
      def property_images
        config.dig('properties') || {}
      end

      # Get all configured content images
      # @return [Hash] Map of image keys to filenames
      def content_images
        config.dig('content') || {}
      end

      # Get all configured team images
      # @return [Hash] Map of image keys to filenames
      def team_images
        config.dig('team') || {}
      end

      # Check if seed images are available (either external URLs or local files)
      # @return [Hash] Status hash with :available, :mode, :message keys
      def availability_status
        if enabled?
          # Check if external URL is reachable
          sample_url = property_url('villa_ocean')
          reachable = check_url_reachable?(sample_url)

          {
            available: reachable,
            mode: :external,
            base_url: base_url,
            message: reachable ? "External R2 images available" : "External R2 images configured but not reachable"
          }
        else
          # Check for local files
          local_path = local_images_path
          local_count = local_image_count

          {
            available: local_count > 0,
            mode: :local,
            path: local_path.to_s,
            count: local_count,
            message: local_count > 0 ? "#{local_count} local images available" : "No local images found"
          }
        end
      end

      # Check availability and print warning if images are not available
      # @param context [String] Description of what's being seeded (e.g., "E2E tests", "seed pack")
      # @return [Boolean] true if images are available
      def check_availability!(context: "seeding")
        status = availability_status

        unless status[:available]
          puts ""
          puts "=" * 60
          puts "WARNING: Seed images not available for #{context}"
          puts "=" * 60

          if status[:mode] == :external
            puts "External URL configured but not reachable:"
            puts "  #{status[:base_url]}"
            puts ""
            puts "Options:"
            puts "  1. Upload images: rails pwb:seed_images:upload"
            puts "  2. Check R2 bucket is public and accessible"
            puts "  3. Unset SEED_IMAGES_BASE_URL to use local files"
          else
            puts "No local images found at:"
            puts "  #{status[:path]}"
            puts ""
            puts "Options:"
            puts "  1. Add images to db/seeds/images/"
            puts "  2. Set SEED_IMAGES_BASE_URL for external R2 images"
            puts "  3. Run: rails pwb:seed_images:check"
          end

          puts ""
          puts "Properties will be created without images."
          puts "=" * 60
          puts ""
        end

        status[:available]
      end

      # Get local images path
      # @return [Pathname]
      def local_images_path
        Rails.root.join('db', 'seeds', 'images')
      end

      # Count local image files
      # @return [Integer]
      def local_image_count
        path = local_images_path
        return 0 unless path.exist?

        Dir.glob(path.join('*.{jpg,jpeg,png,gif,webp}')).count
      end

      private

      # Check if a URL is reachable via HEAD request
      # @param url [String] URL to check
      # @return [Boolean]
      def check_url_reachable?(url)
        require 'net/http'
        require 'uri'

        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.open_timeout = 5
        http.read_timeout = 5

        response = http.head(uri.request_uri)
        response.code.to_i == 200
      rescue StandardError
        false
      end

      def config
        @config ||= load_config
      end

      def load_config
        config_path = Rails.root.join('config', 'seed_images.yml')
        return {} unless File.exist?(config_path)

        yaml = ERB.new(File.read(config_path)).result
        YAML.safe_load(yaml, permitted_classes: [], permitted_symbols: [], aliases: true)
            .fetch(Rails.env, {})
      end

      def build_url(category, image_key)
        # Normalize the key - remove .jpg extension if present
        key = image_key.to_s.sub(/\.jpe?g$/i, '')

        # Look up the filename from config
        filename = config.dig(category.to_s, key)

        # If not found in config, assume the key is the filename
        filename ||= "#{key}.jpg"

        "#{base_url}/#{filename}"
      end
    end
  end
end
