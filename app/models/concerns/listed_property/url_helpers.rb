# frozen_string_literal: true

module ListedProperty
  # Provides URL generation helpers for ListedProperty
  # Used for generating SEO-friendly URLs and contextual paths
  module UrlHelpers
    extend ActiveSupport::Concern

    # Returns a URL-friendly version of the title
    # Falls back to "show" if title is too short
    # @return [String] parameterized title or "show"
    def url_friendly_title
      title && title.length > 2 ? title.parameterize : "show"
    end

    # Returns the slug for URL generation, falling back to ID if no slug
    # @return [String] slug or UUID
    def slug_or_id
      slug.presence || id
    end

    # Generates the appropriate show path based on operation type
    # @param rent_or_sale [String] "for_rent" or "for_sale"
    # @return [String] the property show path
    def contextual_show_path(rent_or_sale)
      rent_or_sale ||= for_rent ? "for_rent" : "for_sale"

      if rent_or_sale == "for_rent"
        Rails.application.routes.url_helpers.prop_show_for_rent_path(
          locale: I18n.locale,
          id: slug_or_id,
          url_friendly_title: url_friendly_title
        )
      else
        Rails.application.routes.url_helpers.prop_show_for_sale_path(
          locale: I18n.locale,
          id: slug_or_id,
          url_friendly_title: url_friendly_title
        )
      end
    end
  end
end
