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

      private

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
