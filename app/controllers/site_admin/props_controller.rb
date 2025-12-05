# frozen_string_literal: true

module SiteAdmin
  # PropsController
  # Manages properties for the current website
  # Uses Pwb::ListedProperty (materialized view) for reads and Pwb::RealtyAsset for writes
  class PropsController < SiteAdminController
    before_action :set_property, only: [:show]
    before_action :set_realty_asset, only: [
      :edit_general, :edit_text, :edit_sale_rental, :edit_location,
      :edit_features, :edit_photos, :upload_photos, :remove_photo,
      :reorder_photos, :update
    ]

    def index
      # Use Pwb::ListedProperty (materialized view) for listing - it's optimized for reads
      # Scope to current website
      @props = Pwb::ListedProperty.where(website_id: current_website&.id).order(created_at: :desc).limit(100)

      if params[:search].present?
        @props = @props.where('reference ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      # @prop set by before_action (uses Property view)
    end

    def edit_general
      render :edit_general
    end

    def edit_text
      # Load listings for text editing - titles/descriptions are on listings now
      @sale_listing = @prop.sale_listings.first
      @rental_listing = @prop.rental_listings.first
      render :edit_text
    end

    def edit_sale_rental
      # Load associated listings for editing
      @sale_listing = @prop.sale_listings.first_or_initialize
      @rental_listing = @prop.rental_listings.first_or_initialize
      render :edit_sale_rental
    end

    def edit_location
      render :edit_location
    end

    def edit_features
      # Load available features from FieldKey where tag is 'extras'
      # If no field keys exist, provide a default set of common property features
      @available_features = Pwb::FieldKey.where(tag: 'extras').visible.pluck(:global_key)

      if @available_features.empty?
        @available_features = %w[
          extras.pool extras.garden extras.terrace extras.balcony
          extras.air_conditioning extras.heating extras.elevator extras.storage
          extras.security extras.video_intercom extras.gated_community extras.parking
          extras.sea_view extras.mountain_view extras.fireplace extras.fitted_kitchen
        ]
      end

      # Get current features for this property
      @current_features = @prop.features.pluck(:feature_key)

      render :edit_features
    end

    def edit_photos
      render :edit_photos
    end

    def upload_photos
      if params[:photos].present?
        max_sort_order = @prop.prop_photos.maximum(:sort_order) || 0
        params[:photos].each_with_index do |photo, index|
          prop_photo = @prop.prop_photos.build(sort_order: max_sort_order + index + 1)
          prop_photo.image.attach(photo)
          prop_photo.save
        end
        redirect_to edit_photos_site_admin_prop_path(@prop), notice: "#{params[:photos].count} photo(s) uploaded successfully."
      else
        redirect_to edit_photos_site_admin_prop_path(@prop), alert: 'No photos selected.'
      end
    end

    def remove_photo
      photo = @prop.prop_photos.find(params[:photo_id])

      if photo.destroy
        redirect_to edit_photos_site_admin_prop_path(@prop), notice: 'Photo removed successfully.'
      else
        redirect_to edit_photos_site_admin_prop_path(@prop), alert: 'Failed to remove photo.'
      end
    end

    def reorder_photos
      if params[:photo_order].present?
        photo_ids = params[:photo_order].split(',')
        photo_ids.each_with_index do |photo_id, index|
          @prop.prop_photos.where(id: photo_id).update_all(sort_order: index + 1)
        end
        redirect_to edit_photos_site_admin_prop_path(@prop), notice: 'Photo order updated successfully.'
      else
        redirect_to edit_photos_site_admin_prop_path(@prop), alert: 'No order specified.'
      end
    end

    def update
      ActiveRecord::Base.transaction do
        # Update the realty asset (physical property data)
        @prop.update!(asset_params) if asset_params.present?

        # Update or create sale listing if sale params present
        if sale_listing_params.present?
          sale_listing = @prop.sale_listings.first_or_initialize
          sale_listing.update!(sale_listing_params)
        end

        # Update or create rental listing if rental params present
        if rental_listing_params.present?
          rental_listing = @prop.rental_listings.first_or_initialize
          rental_listing.update!(rental_listing_params)
        end

        # Update features if features params present
        if params[:features].present?
          update_features(params[:features])
        end
      end

      redirect_to site_admin_prop_path(@prop), notice: 'Property was successfully updated.'
    rescue ActiveRecord::RecordInvalid => e
      redirect_to edit_general_site_admin_prop_path(@prop), alert: "Failed to update property: #{e.message}"
    end

    private

    def set_property
      # Use Property view for read-only show action
      # Scope to current website for security
      @prop = Pwb::ListedProperty.where(website_id: current_website&.id).find(params[:id])
    end

    def set_realty_asset
      # Use RealtyAsset for write operations
      # Scope to current website for security
      @prop = Pwb::RealtyAsset.where(website_id: current_website&.id).find(params[:id])
    end

    def asset_params
      return {} unless params[:pwb_realty_asset].present? || params[:pwb_prop].present?

      param_key = params[:pwb_realty_asset].present? ? :pwb_realty_asset : :pwb_prop
      params.require(param_key).permit(
        :reference,
        :count_bedrooms, :count_bathrooms, :count_garages, :count_toilets,
        :plot_area, :constructed_area, :year_construction,
        :energy_rating, :energy_performance,
        :street_number, :street_name, :street_address, :postal_code,
        :city, :region, :country, :latitude, :longitude,
        :prop_type_key, :prop_state_key, :prop_origin_key
      )
    end

    def sale_listing_params
      return {} unless params[:sale_listing].present?

      # Include title/description for each supported locale
      locale_fields = I18n.available_locales.flat_map do |locale|
        ["title_#{locale}".to_sym, "description_#{locale}".to_sym]
      end

      params.require(:sale_listing).permit(
        :visible, :highlighted, :archived, :reserved, :furnished,
        :price_sale_current_cents, :price_sale_current_currency,
        :commission_cents, :commission_currency,
        *locale_fields
      )
    end

    def rental_listing_params
      return {} unless params[:rental_listing].present?

      # Include title/description for each supported locale
      locale_fields = I18n.available_locales.flat_map do |locale|
        ["title_#{locale}".to_sym, "description_#{locale}".to_sym]
      end

      params.require(:rental_listing).permit(
        :visible, :highlighted, :archived, :reserved, :furnished,
        :for_rent_short_term, :for_rent_long_term,
        :price_rental_monthly_current_cents, :price_rental_monthly_current_currency,
        :price_rental_monthly_low_season_cents, :price_rental_monthly_high_season_cents,
        *locale_fields
      )
    end

    def update_features(features_param)
      # features_param is an array of selected feature keys
      selected_features = Array(features_param)

      # Remove features that are no longer selected
      @prop.features.where.not(feature_key: selected_features).destroy_all

      # Add new features
      selected_features.each do |feature_key|
        @prop.features.find_or_create_by(feature_key: feature_key)
      end
    end
  end
end
