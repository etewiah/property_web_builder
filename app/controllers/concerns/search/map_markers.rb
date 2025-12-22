# frozen_string_literal: true

module Search
  # Extracts map marker generation from SearchController
  # Generates marker data for displaying properties on a map
  module MapMarkers
    extend ActiveSupport::Concern

    private

    # Build map markers for the current properties
    # Only includes properties with valid coordinates
    # @return [Array<Hash>] array of marker data hashes
    def set_map_markers
      @map_markers = @properties.filter_map do |property|
        next unless property.show_map

        build_marker_data(property)
      end
    end

    # Build marker data hash for a single property
    # @param property [Pwb::ListedProperty] the property
    # @return [Hash] marker data including position, title, URLs, and price
    def build_marker_data(property)
      {
        id: property.id,
        title: property.title,
        show_url: property.contextual_show_path(@operation_type),
        image_url: property.primary_image_url,
        display_price: property.contextual_price_with_currency(@operation_type),
        position: {
          lat: property.latitude,
          lng: property.longitude
        }
      }
    end
  end
end
