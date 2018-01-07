require_dependency "pwb/application_controller"

module Pwb
  # class ApiExt::V1::PropsController < ActionController::Base
  class ApiExt::V1::PropsController < JSONAPI::ResourceController
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    skip_before_action :ensure_valid_accept_media_type
    skip_before_action :ensure_correct_media_type
    # feb 2017 - seems above has been replaced
    # https://github.com/cerebris/jsonapi-resources/pull/806/files
    # https://github.com/cerebris/jsonapi-resources/commit/05f873c284f3c084b32140ffdae975667df011fb
    # by below
    # skip_before_action :verify_content_type_header
    # skip_before_action :verify_accept_header

    before_action :cors_preflight_check
    after_action :cors_set_access_control_headers
    # For all responses in this controller, return the CORS access control headers.

    def cors_set_access_control_headers
      headers['Access-Control-Allow-Origin'] = '*'
      headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
      headers['Access-Control-Max-Age'] = "1728000"
    end

    # If this is a preflight OPTIONS request, then short-circuit the
    # request, return only the necessary headers and return an empty
    # text/plain.

    def cors_preflight_check
      if request.method == :options
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
        headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-Prototype-Version'
        headers['Access-Control-Max-Age'] = '1728000'
        render text: '', content_type: 'text/plain'
      end
    end


    def create_with_token
      propertyJSON = params["property"]
      # unless propertiesJSON.is_a? Array
      #   propertiesJSON = JSON.parse propertiesJSON
      # end
      pwb_prop = {}
      message = ""

      if Pwb::Prop.where(reference: propertyJSON["reference"]).exists?
        pwb_prop = Pwb::Prop.find_by_reference propertyJSON["reference"]
        message = "PWB property already exists"
      else
        begin
          pwb_prop = Pwb::Prop.create property_params
           # propertyJSON.except "extras", "property_photos"
          if propertyJSON["extras"]
            pwb_prop.set_extras=propertyJSON["extras"]
          end
          if propertyJSON["property_photos"]
            propertyJSON["property_photos"].each do |property_photo|
              photo = PropPhoto.create
              photo.sort_order = property_photo["sort_order"] || nil
              photo.remote_image_url = property_photo["image"]["url"] || property_photo["url"]
              photo.save!
              pwb_prop.prop_photos.push photo
            end
          end
          message = "PWB property added"
        rescue => err
          # logger.error err.message
          return render_json_error err.message
        end
      end

      return render json: {
        pwb_prop: pwb_prop,
        message: message
      }
    end

    def bulk_create_with_token
      propertiesJSON = params["propertiesJSON"]
      unless propertiesJSON.is_a? Array
        propertiesJSON = JSON.parse propertiesJSON
      end
      new_props = []
      existing_props = []
      errors = []

      propertiesJSON.each do |propertyJSON|
        if Pwb::Prop.where(reference: propertyJSON["reference"]).exists?
          existing_props.push propertyJSON
        else
          begin
            new_prop = Pwb::Prop.create propertyJSON.except "extras", "property_photos"
            if propertyJSON["extras"]
              new_prop.set_extras=propertyJSON["extras"]
            end
            if propertyJSON["property_photos"]
              propertyJSON["property_photos"].each do |property_photo|
                photo = PropPhoto.create
                photo.sort_order = property_photo["sort_order"] || nil
                photo.remote_image_url = property_photo["image"]["url"] || property_photo["url"]
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
        errors: errors
      }
    end

    private

    def render_json_error(message, opts = {})
      render json: message, status: opts[:status] || 422
    end

    def property_params
      params.require(:property).permit(
        :reference, :street_address, :city,
        :postal_code, :price_rental_monthly_current
      )
    end

  end
end
