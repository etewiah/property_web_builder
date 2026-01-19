# frozen_string_literal: true

# Concern for models that need responsive image variant generation.
# When included, automatically schedules background variant generation
# when images are attached.
#
# @example Include in a photo model
#   class PropPhoto < ApplicationRecord
#     include ResponsiveVariantSupport
#     has_one_attached :image
#   end
#
module ResponsiveVariantSupport
  extend ActiveSupport::Concern

  included do
    # Schedule variant generation after commit to ensure record is persisted
    after_commit :schedule_responsive_variant_generation, on: [:create, :update]
  end

  # Manually trigger variant generation (useful for testing or manual backfill)
  # @return [Boolean] true if generation was scheduled, false if skipped
  def generate_responsive_variants!
    return false unless should_generate_variants?

    Pwb::ImageVariantGeneratorJob.perform_later(self.class.name, id)
    true
  end

  # Check if this record should have variants generated
  # @return [Boolean]
  def should_generate_variants?
    return false if external?
    return false unless respond_to?(:image) && image.attached?
    return false unless image.variable?

    true
  end

  private

  def schedule_responsive_variant_generation
    return unless should_generate_variants?
    return unless image_recently_changed?

    Pwb::ImageVariantGeneratorJob.perform_later(self.class.name, id)
  end

  # Check if image attachment changed in this transaction
  # This prevents re-generating variants on unrelated updates
  def image_recently_changed?
    # Check if image was just attached (new blob)
    return true if image.attachment&.created_at && image.attachment.created_at > 30.seconds.ago

    # Check if the record was just created
    return true if created_at && created_at > 30.seconds.ago

    false
  end
end
