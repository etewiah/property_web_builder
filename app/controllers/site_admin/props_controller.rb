# frozen_string_literal: true

module SiteAdmin
  # PropsController
  # Manages properties for the current website
  class PropsController < SiteAdminController
    def index
      @props = Pwb::Prop.order(created_at: :desc).limit(100)

      # Search functionality
      if params[:search].present?
        @props = @props.where('reference ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      @prop = Pwb::Prop.find(params[:id])
    end

    def edit_general
      @prop = Pwb::Prop.find(params[:id])
      render :edit_general
    end

    def edit_text
      @prop = Pwb::Prop.find(params[:id])
      render :edit_text
    end

    def edit_sale_rental
      @prop = Pwb::Prop.find(params[:id])
      render :edit_sale_rental
    end

    def edit_location
      @prop = Pwb::Prop.find(params[:id])
      render :edit_location
    end

    def edit_features
      @prop = Pwb::Prop.find(params[:id])
      render :edit_features
    end

    def edit_photos
      @prop = Pwb::Prop.find(params[:id])
      render :edit_photos
    end

    def upload_photos
      @prop = Pwb::Prop.find(params[:id])
      
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
      @prop = Pwb::Prop.find(params[:id])
      photo = @prop.prop_photos.find(params[:photo_id])
      
      if photo.destroy
        redirect_to edit_photos_site_admin_prop_path(@prop), notice: 'Photo removed successfully.'
      else
        redirect_to edit_photos_site_admin_prop_path(@prop), alert: 'Failed to remove photo.'
      end
    end

    def reorder_photos
      @prop = Pwb::Prop.find(params[:id])
      
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
      @prop = Pwb::Prop.find(params[:id])
      if @prop.update(prop_params)
        redirect_to site_admin_prop_path(@prop), notice: 'Property was successfully updated.'
      else
        # Redirect back to the appropriate edit page based on params
        redirect_to edit_general_site_admin_prop_path(@prop), alert: 'Failed to update property.'
      end
    end

    private

    def prop_params
      params.require(:pwb_prop).permit(
        :reference, :visible, :for_sale, :for_rent_long_term, :for_rent_short_term,
        :count_bedrooms, :count_bathrooms, :count_garages, :count_toilets,
        :plot_area, :constructed_area, :year_construction,
        :price_sale_current_cents, :price_rental_monthly_current_cents,
        :currency, :area_unit, :archived, :highlighted, :sold, :reserved,
        :prop_type_key, :prop_state_key,
        translations_attributes: [:id, :locale, :title, :description]
      )
    end
  end
end
