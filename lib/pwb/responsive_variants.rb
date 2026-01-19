# frozen_string_literal: true

module Pwb
  # Configuration and utilities for responsive image variant generation.
  # This module centralizes breakpoint definitions, format settings, and size presets
  # for generating optimized responsive images.
  #
  # @example Generate variants for an image
  #   widths = Pwb::ResponsiveVariants.widths_for(original_width)
  #   formats = Pwb::ResponsiveVariants.formats_to_generate
  #
  # @example Get transformation options
  #   options = Pwb::ResponsiveVariants.transformations_for(640, :webp)
  #   # => { resize_to_limit: [640, nil], format: :webp, saver: { quality: 80 } }
  #
  module ResponsiveVariants
    # Tailwind CSS-aligned breakpoints for responsive images
    # These widths cover common device sizes and DPR (device pixel ratio) combinations
    # Unified standard: 320 (mobile), 640 (mobile 2x), 1024 (tablet), 1280 (desktop)
    WIDTHS = [320, 640, 1024, 1280].freeze

    # Format configurations with quality settings
    # Order represents preference (best compression first)
    FORMATS = {
      avif: {
        format: :avif,
        saver: { quality: 65, effort: 4 },
        mime_type: "image/avif"
      },
      webp: {
        format: :webp,
        saver: { quality: 80 },
        mime_type: "image/webp"
      },
      jpeg: {
        format: :jpeg,
        saver: { quality: 85 },
        mime_type: "image/jpeg"
      }
    }.freeze

    # Predefined sizes attributes for common layout patterns
    # Use these presets for consistent responsive behavior
    SIZE_PRESETS = {
      # Full-width hero images
      hero: "(min-width: 1280px) 1280px, 100vw",

      # Property cards in grid (3 cols xl, 2 cols md, 1 col mobile)
      card: "(min-width: 1280px) 400px, (min-width: 768px) 50vw, 100vw",

      # Property cards in 4-column grid
      card_sm: "(min-width: 1280px) 300px, (min-width: 1024px) 25vw, (min-width: 768px) 50vw, 100vw",

      # Thumbnail in list view
      thumbnail: "(min-width: 768px) 200px, 150px",

      # Small thumbnail (search results sidebar)
      thumbnail_sm: "100px",

      # Gallery lightbox (full viewport)
      lightbox: "100vw",

      # Content images in articles (max 800px container)
      content: "(min-width: 848px) 800px, calc(100vw - 48px)",

      # Logo/branding (fixed size)
      logo: "200px",

      # Featured property (larger card)
      featured: "(min-width: 1280px) 600px, (min-width: 768px) 50vw, 100vw"
    }.freeze

    class << self
      # Get widths to generate for a given original image width.
      # Filters out sizes larger than the original to avoid upscaling.
      #
      # @param original_width [Integer, nil] Width of the original image in pixels
      # @return [Array<Integer>] Array of widths to generate
      def widths_for(original_width)
        max_width = original_width || 9999
        WIDTHS.select { |w| w <= max_width }
      end

      # Get the list of formats to generate based on server capabilities.
      # AVIF is included only if libvips supports it.
      #
      # @return [Array<Symbol>] Array of format symbols (:avif, :webp, :jpeg)
      def formats_to_generate
        formats = [:webp, :jpeg]
        formats.unshift(:avif) if avif_supported?
        formats
      end

      # Check if AVIF format is supported by the current libvips installation.
      #
      # @return [Boolean] true if AVIF encoding is available
      def avif_supported?
        return @avif_supported if defined?(@avif_supported)

        @avif_supported = begin
          # AVIF support requires libvips 8.9+ with AVIF encoder
          defined?(Vips) && Vips.at_least_libvips?(8, 9) && vips_has_avif_saver?
        rescue StandardError
          false
        end
      end

      # Get the sizes attribute value for a preset.
      #
      # @param preset [Symbol, String] Preset name or custom sizes string
      # @return [String] CSS sizes attribute value
      def sizes_for(preset)
        return preset if preset.is_a?(String)

        SIZE_PRESETS[preset.to_sym] || SIZE_PRESETS[:card]
      end

      # Build transformation options for a given width and format.
      #
      # @param width [Integer] Target width in pixels
      # @param format [Symbol] Target format (:avif, :webp, :jpeg)
      # @return [Hash] ActiveStorage variant transformation options
      def transformations_for(width, format)
        format_config = FORMATS[format.to_sym] || FORMATS[:jpeg]

        if Rails.application.config.active_storage.variant_processor == :vips
          {
            resize_to_limit: [width, nil],
            format: format_config[:format],
            saver: format_config[:saver]
          }
        else
          # MiniMagick / ImageMagick options
          # format and quality are top-level options
          options = {
            resize_to_limit: [width, nil],
            format: format_config[:format]
          }
          
          # Add quality if defined in saver config
          if format_config[:saver] && format_config[:saver][:quality]
            options[:quality] = format_config[:saver][:quality]
          end
          
          options
        end
      end

      # Get MIME type for a format.
      #
      # @param format [Symbol] Format symbol
      # @return [String] MIME type string
      def mime_type_for(format)
        FORMATS[format.to_sym]&.fetch(:mime_type, "image/jpeg")
      end

      private

      def vips_has_avif_saver?
        # Check if Vips can actually save AVIF
        # This accounts for libvips compiled without AVIF support
        return false unless defined?(Vips)

        Vips.get_suffixes.include?(".avif")
      rescue StandardError
        false
      end
    end
  end
end
