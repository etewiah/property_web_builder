# frozen_string_literal: true

# Property::Geocodable
#
# Provides geocoding functionality for property models.
# Uses the geocoder gem to convert addresses to coordinates.
#
module Property
  module Geocodable
    extend ActiveSupport::Concern

    included do
      geocoded_by :geocodeable_address do |obj, results|
        if (geo = results.first)
          obj.longitude = geo.longitude
          obj.latitude = geo.latitude
          obj.city = geo.city
          obj.street_number = geo.street_number
          obj.street_address = geo.street_address
          obj.postal_code = geo.postal_code
          obj.province = geo.province
          obj.region = geo.state
          obj.country = geo.country
        end
      end
    end

    def geocodeable_address
      "#{street_address} , #{city} , #{province} , #{postal_code}"
    end

    def geocode_address!
      geocode
    end

    def geocode_address_if_needed!
      return if latitude.present? && longitude.present?
      geocode_address!
    end

    def needs_geocoding?
      geocodeable_address.present? && (latitude.blank? || longitude.blank?)
    end

    def show_map
      latitude.present? && longitude.present? && !hide_map
    end
  end
end
