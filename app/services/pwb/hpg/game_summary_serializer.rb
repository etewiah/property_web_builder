# frozen_string_literal: true

module Pwb
  module Hpg
    # Serializes a RealtyGame with full listing data for gameplay
    class GameSummarySerializer
      def self.call(game)
        listings = game.game_listings
                       .visible
                       .ordered
                       .includes(realty_asset: :prop_photos)

        {
          slug: game.slug,
          title: game.title,
          description: game.description,
          bg_image_url: game.bg_image_url,
          default_currency: game.default_currency,
          default_country: game.default_country,
          validation_rules: game.validation_rules,
          listings: listings.map { |gl| serialize_listing(gl) }
        }
      end

      def self.serialize_listing(game_listing)
        asset = game_listing.realty_asset
        photos = asset.prop_photos.first(5)

        {
          id: asset.id,
          game_listing_id: game_listing.id,
          display_title: game_listing.display_title || asset.title,
          sort_order: game_listing.sort_order,
          property: {
            uuid: asset.id,
            street_address: asset.street_address,
            city: asset.city,
            country: asset.country,
            bedrooms: asset.count_bedrooms,
            bathrooms: asset.count_bathrooms,
            area_sqm: asset.constructed_area,
            latitude: asset.latitude,
            longitude: asset.longitude,
            photos: photos.map { |p| { id: p.id, url: p.image_url, thumbnail_url: p.thumbnail_url } }
          }
        }
      end
    end
  end
end
