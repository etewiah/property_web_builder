module Pwb
  class Api::V1::PropertiesController < JSONAPI::ResourceController
    protect_from_forgery with: :null_session
    before_action :set_current_website
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    # skip_before_action :ensure_valid_accept_media_type

    # def set_default_currency
    #   @model
    # end

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
        if current_website.props.where(reference: propertyJSON["reference"]).exists?
          existing_props.push current_website.props.find_by_reference propertyJSON["reference"]
          # propertyJSON
        else
          begin
            new_prop = current_website.props.create(property_params)
            # new_prop = Pwb::Prop.create(propertyJSON.except("features", "property_photos", "image_urls", "last_retrieved_at"))

            # create will use website defaults for currency and area_unit
            # need to override that
            if propertyJSON["currency"]
              new_prop.currency = propertyJSON["currency"]
              new_prop.save!
            end
            if propertyJSON["area_unit"]
              new_prop.area_unit = propertyJSON["area_unit"]
              new_prop.save!
            end

            # TODO - go over supported locales and save title and description
            # into them

            # if propertyJSON["features"]
            # TODO - process feature (currently not retrieved by PWS so not important)
            #   new_prop.set_features=propertyJSON["features"]
            # end
            if propertyJSON["property_photos"]
              # uploading images can slow things down so worth setting a limit
              max_photos_to_process = 20
              # TODO - retrieve above as a param
              propertyJSON["property_photos"].each_with_index do |property_photo, index|
                if index > max_photos_to_process
                  return
                end
                photo = PropPhoto.create
                photo.sort_order = property_photo["sort_order"] || nil
                photo.remote_image_url = property_photo["url"]
                # photo.remote_image_url = property_photo["image"]["url"] || property_photo["url"]
                photo.save!
                new_prop.prop_photos.push photo
              end
            end

            new_props.push new_prop
          rescue => err
            errors.push err.message
            # logger.error err.message
          end
        end
      end

      return render json: {
                      new_props: new_props,
                      existing_props: existing_props,
                      errors: errors,
                    }
    end

    # TODO: rename to update_features:
    def update_extras
      property = current_website.props.find(params[:id])
      # The set_features method goes through ea
      property.set_features = params[:extras].to_unsafe_hash
      property.save!
      return render json: property.features
    end

    def order_photos
      ordered_photo_ids = params[:ordered_photo_ids]
      ordered_array = ordered_photo_ids.split(",")
      ordered_array.each.with_index(1) do |photo_id, index|
        photo = PropPhoto.find(photo_id)
        photo.sort_order = index
        photo.save!
      end
      @property = current_website.props.find(params[:prop_id])
      return render json: @property.prop_photos
      # { "success": true }, status: :ok, head: :no_content
    end

    def add_photo_from_url
      # subdomain = request.subdomain || ""

      property = current_website.props.find(params[:id])
      remote_urls = params[:remote_urls].split(",")
      photos_array = []
      remote_urls.each do |remote_url|
        photo = PropPhoto.create
        # photo.subdomain = subdomain
        # photo.folder = current_tenant_model.whitelabel_country_code
        # photo.tenant_id = current_tenant_model.id
        # need the regex below to remove leading and trailing quotationmarks
        # photo.remote_image_url = remote_url.gsub!(/\A"|"\Z/, '')
        photo.remote_image_url = remote_url
        photo.save!
        property.prop_photos.push photo
        photos_array.push photo
      end
      # if json below is not valid, success callback on client will fail
      return render json: photos_array.to_json
      # { "success": true }, status: :ok, head: :no_content
    end

    def add_photo
      # subdomain = request.subdomain || ""

      property = Prop.find(params[:id])
      files_array = params[:file]
      if files_array.class.to_s == "ActionDispatch::Http::UploadedFile"
        # In case a single file has been sent, use as an array item
        files_array = [files_array]
      end
      photos_array = []
      files_array.each do |file|
        photo = PropPhoto.create
        # photo.subdomain = subdomain
        # photo.folder = current_tenant_model.whitelabel_country_code
        # photo.tenant_id = current_tenant_model.id
        photo.image = file
        photo.save!

        # photo.update_attributes(:url => photo.image.metadata['url'])
        # ul = Pwb::PropPhotoUploader.new
        # ul.store!(file)
        # tried various options like above to ensure photo.image.url
        # which is nil at this point gets updated
        # - in the end it was just a reload that was needed:
        photo.reload

        property.prop_photos.push photo
        photos_array.push photo
      end

      # if json below is not valid, success callback on client will fail
      return render json: photos_array.to_json
      # { "success": true }, status: :ok, head: :no_content
    end

    def remove_photo
      photo = PropPhoto.find(params[:id])
      property = Prop.find(params[:prop_id])
      property.prop_photos.destroy photo
      # if json below is not valid, success callback on client will fail
      return render json: { "success": true }, status: :ok, head: :no_content
    end

    # def set_owner
    #   property = Prop.find(params[:prop_id])
    #   client = Client.find(params[:client_id])
    #   property.owners = [client]
    #   property.save!
    #   return render json: "success"
    # end

    # def unset_owner
    #   property = Prop.find(params[:prop_id])
    #   client = Client.find(params[:client_id])
    #   property.owners = []
    #   property.save!
    #   return render json: "success"
    # end

    private

    def set_current_website
      Pwb::Current.website = current_website_from_subdomain
    end

    def current_website_from_subdomain
      return nil unless request.subdomain.present?
      Website.find_by_subdomain(request.subdomain)
    end

    def properties_params(propertiesJSON)
      # propertiesJSON = params["propertiesJSON"]
      # unless propertiesJSON.is_a? Array
      #   propertiesJSON = JSON.parse propertiesJSON
      # end
      # pp = ActionController::Parameters.new(propertiesJSON)
      pp = ActionController::Parameters.new({ propertiesJSON: propertiesJSON })
      # https://github.com/rails/strong_parameters/issues/140
      # params.require(:propertiesJSON).map do |p|
      pp.require(:propertiesJSON).map do |p|
        p.permit(
          :title, :description,
          :reference, :street_address, :city,
          :postal_code, :price_rental_monthly_current,
          :for_rent_short_term, :visible,
          :count_bedrooms, :count_bathrooms,
          :longitude, :latitude
        )
        # ActionController::Parameters.new(p.to_hash).permit(:title, :description)
      end
    end
  end
end
