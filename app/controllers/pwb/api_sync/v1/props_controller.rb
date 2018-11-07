# require_dependency "pwb/application_controller"

module Pwb
  class ApiSync::V1::PropsController < ActionController::Base

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

    def index
      unless params["token"] == "20182018"
        return render_json_error "Invalid Token"
      end
      properties = Pwb::Prop.all


      message = "Property published"
      render json: {
        properties: properties.as_json,
        message: message
      }
    end


    private

    def render_json_error(message, opts = {})
      render json: message, status: opts[:status] || 422
    end

  end
end
