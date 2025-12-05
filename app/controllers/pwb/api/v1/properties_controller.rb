module Pwb
  class Api::V1::PropertiesController < ApplicationController
    protect_from_forgery with: :null_session
    before_action :set_current_website

    # DEPRECATION WARNING: This controller uses the deprecated Pwb::Prop model for write operations.
    # Property data should now be created via Pwb::RealtyAsset + Pwb::SaleListing/Pwb::RentalListing.
    # Read operations use Pwb::ListedProperty (materialized view).

    # GET /api/v1/properties
    def index
      properties = current_properties
      render json: serialize_properties(properties)
    end

    # GET /api/v1/properties/:id
    def show
      property = current_properties.find(params[:id])
      render json: serialize_property(property)
    end

    def bulk_create
      propertiesJSON = params["propertiesJSON"]
      unless propertiesJSON.is_a? Array
        propertiesJSON = JSON.parse propertiesJSON
      end
      new_props = []
      existing_props = []
      errors = []
      properties_params(propertiesJSON).each_with_index do |property_params, index|
        propertyJSON = propertiesJSON[index]
        if Pwb::Current.website.props.where(reference: propertyJSON["reference"]).exists?
          existing_props.push Pwb::Current.website.props.find_by_reference propertyJSON["reference"]
        else
          begin
            new_prop = Pwb::Current.website.props.create(property_params)

            if propertyJSON["currency"]
              new_prop.currency = propertyJSON["currency"]
              new_prop.save!
            end
            if propertyJSON["area_unit"]
              new_prop.area_unit = propertyJSON["area_unit"]
              new_prop.save!
            end

            if propertyJSON["property_photos"]
              max_photos_to_process = 20
              propertyJSON["property_photos"].each_with_index do |property_photo, photo_index|
                if photo_index > max_photos_to_process
                  break
                end
                photo = PropPhoto.create
                photo.sort_order = property_photo["sort_order"] || nil
                photo.remote_image_url = property_photo["url"]
                photo.save!
                new_prop.prop_photos.push photo
              end
            end

            new_props.push new_prop
          rescue => err
            errors.push err.message
          end
        end
      end

      render json: {
        new_props: new_props,
        existing_props: existing_props,
        errors: errors
      }
    end

    def update_extras
      property = Pwb::Current.website.props.find(params[:id])
      property.set_features = params[:extras].to_unsafe_hash
      property.save!
      render json: property.features
    end

    def order_photos
      ordered_photo_ids = params[:ordered_photo_ids]
      ordered_array = ordered_photo_ids.split(",")
      ordered_array.each.with_index(1) do |photo_id, index|
        photo = PropPhoto.find(photo_id)
        photo.sort_order = index
        photo.save!
      end
      @property = Pwb::Current.website.props.find(params[:prop_id])
      render json: @property.prop_photos
    end

    def add_photo_from_url
      property = Pwb::Current.website.props.find(params[:id])
      remote_urls = params[:remote_urls].split(",")
      photos_array = []
      remote_urls.each do |remote_url|
        photo = PropPhoto.create
        photo.remote_image_url = remote_url
        photo.save!
        property.prop_photos.push photo
        photos_array.push photo
      end
      render json: photos_array.to_json
    end

    def add_photo
      property = Pwb::Current.website.props.find(params[:id])
      files_array = params[:file]
      if files_array.class.to_s == "ActionDispatch::Http::UploadedFile"
        files_array = [files_array]
      end
      photos_array = []
      files_array.each do |file|
        photo = PropPhoto.create
        photo.image = file
        photo.save!
        photo.reload
        property.prop_photos.push photo
        photos_array.push photo
      end
      render json: photos_array.to_json
    end

    def remove_photo
      photo = PropPhoto.find(params[:id])
      property = Pwb::Current.website.props.find(params[:prop_id])
      property.prop_photos.destroy photo
      render json: { success: true }, status: :ok
    end

    private

    def current_properties
      if Pwb::Current.website
        Pwb::ListedProperty.where(website_id: Pwb::Current.website.id)
      else
        Pwb::ListedProperty.none
      end
    end

    def serialize_properties(properties)
      {
        data: properties.map { |p| serialize_property_data(p) }
      }
    end

    def serialize_property(property)
      {
        data: serialize_property_data(property)
      }
    end

    def serialize_property_data(property)
      {
        id: property.id.to_s,
        type: "properties",
        attributes: {
          "title" => property.title,
          "description" => property.description,
          "title-en" => property.title_en,
          "description-en" => property.description_en,
          "title-es" => property.title_es,
          "description-es" => property.description_es,
          "title-it" => property.title_it,
          "description-it" => property.description_it,
          "title-de" => property.title_de,
          "description-de" => property.description_de,
          "title-ru" => property.title_ru,
          "description-ru" => property.description_ru,
          "title-pt" => property.title_pt,
          "description-pt" => property.description_pt,
          "title-fr" => property.title_fr,
          "description-fr" => property.description_fr,
          "title-tr" => property.title_tr,
          "description-tr" => property.description_tr,
          "title-nl" => property.title_nl,
          "description-nl" => property.description_nl,
          "title-vi" => property.title_vi,
          "description-vi" => property.description_vi,
          "title-ar" => property.title_ar,
          "description-ar" => property.description_ar,
          "title-ca" => property.title_ca,
          "description-ca" => property.description_ca,
          "title-pl" => property.title_pl,
          "description-pl" => property.description_pl,
          "title-ro" => property.title_ro,
          "description-ro" => property.description_ro,
          "title-ko" => property.title_ko,
          "description-ko" => property.description_ko,
          "title-bg" => property.title_bg,
          "description-bg" => property.description_bg,
          "photos" => serialize_photos(property),
          "property-photos" => serialize_photos(property),
          "extras" => property.get_features,
          "street-address" => property.street_address,
          "street-name" => property.street_name,
          "street-number" => property.street_number,
          "postal-code" => property.postal_code,
          "city" => property.city,
          "region" => property.region,
          "currency" => property.currency,
          "country" => property.country,
          "longitude" => property.longitude,
          "latitude" => property.latitude,
          "count-bathrooms" => property.count_bathrooms,
          "count-bedrooms" => property.count_bedrooms,
          "count-garages" => property.count_garages,
          "count-toilets" => property.count_toilets,
          "constructed-area" => property.constructed_area,
          "year-construction" => property.year_construction,
          "plot-area" => property.plot_area,
          "prop-type-key" => property.prop_type_key,
          "prop-state-key" => property.prop_state_key,
          "prop-origin-key" => property.prop_origin_key,
          "for-sale" => property.for_sale,
          "for-rent" => property.for_rent,
          "for-rent-short-term" => property.for_rent_short_term,
          "for-rent-long-term" => property.for_rent_long_term,
          "hide-map" => property.hide_map,
          "obscure-map" => property.obscure_map,
          "price-sale-current-cents" => property.price_sale_current_cents,
          "price-rental-monthly-current-cents" => property.price_rental_monthly_current_cents,
          "price-rental-monthly-low-season-cents" => property.price_rental_monthly_low_season_cents,
          "price-rental-monthly-high-season-cents" => property.price_rental_monthly_high_season_cents,
          "price-rental-monthly-for-search-cents" => property.price_rental_monthly_for_search_cents,
          "visible" => property.visible,
          "highlighted" => property.highlighted,
          "reference" => property.reference
        }
      }
    end

    def serialize_photos(property)
      property.prop_photos.map do |photo|
        photo.attributes.merge({
          "image" => photo.image.attached? ? Rails.application.routes.url_helpers.rails_blob_path(photo.image, only_path: true) : nil
        })
      end
    end

    def set_current_website
      Pwb::Current.website = current_website_from_subdomain
    end

    def current_website_from_subdomain
      return nil unless request.subdomain.present?
      Website.find_by_subdomain(request.subdomain)
    end

    def properties_params(propertiesJSON)
      pp = ActionController::Parameters.new({ propertiesJSON: propertiesJSON })
      pp.require(:propertiesJSON).map do |p|
        p.permit(
          :title, :description,
          :reference, :street_address, :city,
          :postal_code, :price_rental_monthly_current,
          :for_rent_short_term, :visible,
          :count_bedrooms, :count_bathrooms,
          :longitude, :latitude
        )
      end
    end
  end
end
