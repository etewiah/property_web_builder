# frozen_string_literal: true

module Pwb
  # Service for generating responsive image variants at multiple sizes and formats.
  # Works with ActiveStorage attachments to pre-generate optimized variants
  # for responsive image delivery.
  #
  # @example Generate all variants for a photo
  #   generator = Pwb::ResponsiveVariantGenerator.new(photo.image)
  #   if generator.generate_all!
  #     puts "All variants generated successfully"
  #   else
  #     puts "Errors: #{generator.errors}"
  #   end
  #
  # @example Generate a single variant
  #   generator = Pwb::ResponsiveVariantGenerator.new(photo.image)
  #   generator.generate_variant(640, :webp)
  #
  class ResponsiveVariantGenerator
    attr_reader :attachment, :errors

    # Initialize the generator with an ActiveStorage attachment.
    #
    # @param attachment [ActiveStorage::Attached::One] The image attachment
    def initialize(attachment)
      @attachment = attachment
      @errors = []
    end

    # Generate all responsive variants for the attachment.
    # Creates variants at all configured widths and formats.
    #
    # @return [Boolean] true if all variants generated successfully, false if any errors
    def generate_all!
      return false unless valid?

      generated_count = 0
      total_variants = widths_to_generate.size * formats_to_generate.size

      widths_to_generate.each do |width|
        formats_to_generate.each do |format|
          if generate_variant(width, format)
            generated_count += 1
          end
        end
      end

      Rails.logger.info(
        "[ResponsiveVariantGenerator] Generated #{generated_count}/#{total_variants} variants " \
        "for #{attachment.blob.filename}"
      )

      errors.empty?
    end

    # Generate a single variant at the specified width and format.
    #
    # @param width [Integer] Target width in pixels
    # @param format [Symbol] Target format (:avif, :webp, :jpeg)
    # @return [Boolean] true if variant generated successfully
    def generate_variant(width, format)
      transformations = ResponsiveVariants.transformations_for(width, format)

      # Call processed to ensure the variant is generated and stored
      variant = attachment.variant(transformations)
      variant.processed

      Rails.logger.debug(
        "[ResponsiveVariantGenerator] Generated #{width}w #{format} for #{attachment.blob.filename}"
      )
      true
    rescue StandardError => e
      @errors << { width: width, format: format, error: e.message }
      Rails.logger.error(
        "[ResponsiveVariantGenerator] Failed to generate #{width}w #{format}: #{e.message}"
      )
      false
    end

    # Get URL for a specific variant (useful for building srcset).
    #
    # @param width [Integer] Target width in pixels
    # @param format [Symbol] Target format
    # @return [String, nil] URL for the variant or nil if generation fails
    def variant_url(width, format)
      return nil unless valid?

      transformations = ResponsiveVariants.transformations_for(width, format)
      Rails.application.routes.url_helpers.url_for(attachment.variant(transformations))
    rescue StandardError => e
      Rails.logger.warn("[ResponsiveVariantGenerator] variant_url failed: #{e.message}")
      nil
    end

    # Build a srcset string for a given format.
    #
    # @param format [Symbol] Target format (:avif, :webp, :jpeg)
    # @return [String] srcset attribute value
    def build_srcset(format)
      return "" unless valid?

      entries = widths_to_generate.map do |width|
        url = variant_url(width, format)
        next nil unless url

        "#{url} #{width}w"
      end.compact

      entries.join(", ")
    end

    # Check if the attachment is valid for variant generation.
    #
    # @return [Boolean]
    def valid?
      validate
      @validated_errors.empty?
    end

    private

    def validate
      return if defined?(@validated_errors)

      @validated_errors = []

      unless attachment&.attached?
        @validated_errors << { error: "No attachment present" }
        return
      end

      unless attachment.variable?
        @validated_errors << { error: "Attachment is not a variable image (cannot be resized)" }
        return
      end

      if external_image?
        @validated_errors << { error: "External images cannot generate variants" }
      end
    end

    def external_image?
      record = attachment.record
      record.respond_to?(:external_url) && record.external_url.present?
    end

    def widths_to_generate
      ResponsiveVariants.widths_for(original_width)
    end

    def formats_to_generate
      ResponsiveVariants.formats_to_generate
    end

    def original_width
      attachment.blob.metadata[:width]
    end
  end
end
