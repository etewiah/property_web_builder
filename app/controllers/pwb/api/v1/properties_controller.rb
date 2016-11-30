module Pwb
  class Api::V1::PropertiesController < JSONAPI::ResourceController
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    skip_before_action :ensure_valid_accept_media_type

    # def set_default_currency
    #   binding.pry
    #   @model
    # end


    def update_extras
      property = Prop.find(params[:id])
      property.set_extras = params[:extras]
      property.save!
      return render json: property.features
    end

    # def order_photos
    #   ordered_photo_ids = params[:ordered_photo_ids]
    #   ordered_array = ordered_photo_ids.split(",")
    #   ordered_array.each.with_index(1) do |photo_id, index|
    #     photo = PropPhoto.find(photo_id)
    #     photo.number = index
    #     photo.save!
    #   end
    #   @property = Prop.find(params[:property_id])
    #   return render json: @property.property_photos
    #   # { "success": true }, status: :ok, head: :no_content
    # end

    # def add_photo_from_url
    #   subdomain = request.subdomain || ""
    #   # all this so I can get whitelabel_country_code
    #   current_tenant_model = Tenant.get_from_subdomain subdomain

    #   property = Prop.find(params[:id])
    #   remote_urls = params[:remote_urls].split(",")
    #   photos_array = []
    #   remote_urls.each do |remote_url|
    #     photo = PropPhoto.create
    #     photo.subdomain = subdomain
    #     photo.folder = current_tenant_model.whitelabel_country_code
    #     photo.tenant_id = current_tenant_model.id
    #     # need the regex below to remove leading and trailing quotationmarks
    #     # photo.remote_image_url = remote_url.gsub!(/\A"|"\Z/, '')
    #     photo.remote_image_url = remote_url
    #     photo.save!
    #     property.property_photos.push photo
    #     photos_array.push photo
    #   end
    #   # if json below is not valid, success callback on client will fail
    #   return render json: photos_array.to_json
    #   # { "success": true }, status: :ok, head: :no_content
    # end

    # def add_photo
    #   # current_tenant = Apartment::Tenant.current
    #   subdomain = request.subdomain || ""
    #   # all this so I can get whitelabel_country_code
    #   current_tenant_model = Tenant.get_from_subdomain subdomain

    #   property = Prop.find(params[:id])
    #   files_array = params[:file]
    #   photos_array = []
    #   files_array.each do |file|
    #     photo = PropPhoto.create
    #     photo.subdomain = subdomain
    #     photo.folder = current_tenant_model.whitelabel_country_code
    #     photo.tenant_id = current_tenant_model.id
    #     photo.image = file
    #     photo.save!
    #     property.property_photos.push photo
    #     photos_array.push photo
    #   end
    #   # if json below is not valid, success callback on client will fail
    #   return render json: photos_array.to_json
    #   # { "success": true }, status: :ok, head: :no_content
    # end

    # def remove_photo
    #   photo = PropPhoto.find(params[:id])
    #   property = Prop.find(params[:property_id])
    #   property.property_photos.destroy photo
    #   # if json below is not valid, success callback on client will fail
    #   return render json: { "success": true }, status: :ok, head: :no_content
    # end

    # def set_owner
    #   property = Prop.find(params[:property_id])
    #   client = Client.find(params[:client_id])
    #   property.owners = [client]
    #   property.save!
    #   return render json: "success"
    # end

    # def unset_owner
    #   property = Prop.find(params[:property_id])
    #   client = Client.find(params[:client_id])
    #   property.owners = []
    #   property.save!
    #   return render json: "success"
    # end

  end
end
