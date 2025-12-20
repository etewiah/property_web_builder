# frozen_string_literal: true

# SEO field validations for listings
# Validates title and meta_description lengths per locale
#
# Recommended lengths:
# - SEO Title: 50-60 chars (warns over 60, max 70)
# - Meta Description: 150-160 chars (warns over 160, max 200)
#
module SeoValidatable
  extend ActiveSupport::Concern

  SEO_TITLE_MAX_LENGTH = 70
  META_DESCRIPTION_MAX_LENGTH = 200

  included do
    validate :validate_seo_field_lengths
  end

  private

  def validate_seo_field_lengths
    I18n.available_locales.each do |locale|
      validate_seo_title_for_locale(locale)
      validate_meta_description_for_locale(locale)
    end
  end

  def validate_seo_title_for_locale(locale)
    field_name = "seo_title_#{locale}"
    value = send(field_name) if respond_to?(field_name)
    return if value.blank?

    if value.length > SEO_TITLE_MAX_LENGTH
      errors.add(field_name.to_sym, "is too long (maximum is #{SEO_TITLE_MAX_LENGTH} characters, got #{value.length})")
    end
  end

  def validate_meta_description_for_locale(locale)
    field_name = "meta_description_#{locale}"
    value = send(field_name) if respond_to?(field_name)
    return if value.blank?

    if value.length > META_DESCRIPTION_MAX_LENGTH
      errors.add(field_name.to_sym, "is too long (maximum is #{META_DESCRIPTION_MAX_LENGTH} characters, got #{value.length})")
    end
  end
end
