require_dependency "pwb/application_controller"

module Pwb
  class ApiPublic::V1::PropsController < ActionController::Base
  # class ApiPublic::V1::PropsController < JSONAPI::ResourceController
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    # skip_before_action :ensure_valid_accept_media_type
    # feb 2017 - seems above has been replaced
    # https://github.com/cerebris/jsonapi-resources/pull/806/files
    # https://github.com/cerebris/jsonapi-resources/commit/05f873c284f3c084b32140ffdae975667df011fb
    # by below
    # verify_content_type_header
    # verify_accept_header

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
            # binding.pry
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

  end
end
