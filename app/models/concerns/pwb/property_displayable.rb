# frozen_string_literal: true

# Property::Displayable
#
# Provides display and URL helper methods for property models.
# Handles image URLs, titles, and path generation.
#
module Pwb
  module PropertyDisplayable
    extend ActiveSupport::Concern

    def url_friendly_title
      if title && title.length > 2
        title.parameterize
      else
        'show'
      end
    end

    def contextual_show_path(rent_or_sale)
      rent_or_sale ||= for_rent ? 'for_rent' : 'for_sale'
      if rent_or_sale == 'for_rent'
        Rails.application.routes.url_helpers.prop_show_for_rent_path(
          locale: I18n.locale, id: id, url_friendly_title: url_friendly_title
        )
      else
        Rails.application.routes.url_helpers.prop_show_for_sale_path(
          locale: I18n.locale, id: id, url_friendly_title: url_friendly_title
        )
      end
    end

    def ordered_photo(number)
      prop_photos[number - 1] if prop_photos.length >= number
    end

    def primary_image_url
      if prop_photos.length.positive? && ordered_photo(1).image.attached?
        Rails.application.routes.url_helpers.rails_blob_path(ordered_photo(1).image, only_path: true)
      else
        ''
      end
    end

    def extras_for_display
      merged_extras = []
      get_features.keys.each do |extra|
        translated_option_key = I18n.t(extra)
        merged_extras.push(translated_option_key)
      end
      merged_extras.sort { |w1, w2| w1.casecmp(w2) }
    end
  end
end
