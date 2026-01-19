# frozen_string_literal: true

module Pwb
  # Background job for generating responsive image variants.
  # This job is triggered after image uploads to pre-generate all
  # responsive variants, ensuring fast delivery of optimized images.
  #
  # @example Enqueue for a PropPhoto
  #   Pwb::ImageVariantGeneratorJob.perform_later("Pwb::PropPhoto", photo.id)
  #
  class ImageVariantGeneratorJob < ApplicationJob
    queue_as :images

    # Retry with exponential backoff for transient failures
    retry_on StandardError, wait: :polynomially_longer, attempts: 3

    # Don't retry if the record was deleted
    discard_on ActiveRecord::RecordNotFound

    # @param model_class [String] Fully qualified class name of the photo model
    # @param model_id [Integer] ID of the photo record
    def perform(model_class, model_id)
      record = model_class.constantize.find(model_id)
      attachment = find_attachment(record)

      unless attachment&.attached?
        Rails.logger.info(
          "[ImageVariantGeneratorJob] Skipping #{model_class}##{model_id} - no attachment"
        )
        return
      end

      # Skip external images (URLs, not uploads)
      if record.respond_to?(:external_url) && record.external_url.present?
        Rails.logger.info(
          "[ImageVariantGeneratorJob] Skipping #{model_class}##{model_id} - external URL"
        )
        return
      end

      generator = ResponsiveVariantGenerator.new(attachment)

      if generator.generate_all!
        Rails.logger.info(
          "[ImageVariantGeneratorJob] Successfully generated variants for #{model_class}##{model_id}"
        )
      else
        Rails.logger.warn(
          "[ImageVariantGeneratorJob] Partial failure for #{model_class}##{model_id}: " \
          "#{generator.errors.inspect}"
        )
      end
    end

    private

    def find_attachment(record)
      case record
      when Pwb::PropPhoto, Pwb::ContentPhoto, Pwb::WebsitePhoto
        record.image
      when Pwb::Media
        record.file
      else
        # Generic fallback - try common attachment names
        record.try(:image) || record.try(:file)
      end
    end
  end
end
