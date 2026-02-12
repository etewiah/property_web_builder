# frozen_string_literal: true

module ApiPublic
  module V1
    module Hpg
      class ListingsController < BaseController
        # GET /api_public/v1/hpg/listings/:uuid
        def show
          expires_in 1.hour, public: true

          asset = current_website.realty_assets.find(params[:uuid])
          photos = asset.prop_photos.limit(10)

          render json: {
            uuid: asset.id,
            reference: asset.reference,
            title: asset.title,
            street_address: asset.street_address,
            city: asset.city,
            country: asset.country,
            postal_code: asset.postal_code,
            bedrooms: asset.count_bedrooms,
            bathrooms: asset.count_bathrooms,
            area_sqm: asset.constructed_area,
            latitude: asset.latitude,
            longitude: asset.longitude,
            prop_type: asset.prop_type_key,
            photos: photos.map { |p| { id: p.id, url: p.image_url, thumbnail_url: p.thumbnail_url } }
          }
        end
      end
    end
  end
end
