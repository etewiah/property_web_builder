require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::AgencyController < ApplicationApiController

    # protect_from_forgery with: :null_session

    def infos
      return render json: {
        data: []
      }
    end

    def show
      @agency = Agency.last
      if @agency
        return render json: {
          #TODO - change legacy admin code to retrieve info below
          #from agency
          # and to use supported_locales instead of supported_languages
          tenant:             @agency.as_json(
            :only =>
            ["social_media","default_client_locale",
             "default_admin_locale","raw_css","site_template_id"],
            :methods => ["style_variables","supported_languages",
                         "available_locales"]),
          # supported_languages: [:en,:es]

          agency: @agency,
          primary_address: @agency.primary_address
          # current_user: current_user.as_json(:only => ["email", "first_names","last_names","phone_number_primary","skype"])
        }

      else
        return render json: {
          tenant: {},
          agency: {},
          primary_address: {},
          # current_user: current_user.as_json(:only => ["email", "first_names","last_names","phone_number_primary","skype"])
        }

      end
    end

    def update
      @agency = Agency.last
      if @agency
        @agency.update(agency_params)
        # http://patshaughnessy.net/2014/6/16/a-rule-of-thumb-for-strong-parameters
        # adding :social_media to the list permitted by strong params does not work so doing below
        # which is  ugly but works
        @agency.social_media = params[:agency][:social_media]
        @agency.save!
      end
      return render json: @agency
    end

    def update_legacy
      @agency = Agency.last

      @agency.style_variables = params[:style_variables]
      @agency.social_media = params[:social_media]

      # ActionController::Base.helpers.sanitize_css
      # TODO - allow raw_css after sanitizing with above
      # @agency.raw_css = params[:raw_css]

      if params[:site_template_id].present?
        # TODO - verify site_template exists
        @agency.site_template_id = params[:site_template_id]
      end
      # TODO - rename supported_languages client side
      @agency.supported_locales = params[:supported_languages]
      @agency.save!
      
      return render json: { "success": true }, status: :ok, head: :no_content
    end


    def update_master_address
      @agency = Agency.last
      if @agency.primary_address
        @agency.primary_address.update(address_params)
        @agency.primary_address.save!
      else
        primary_address = Address.create(address_params)
        @agency.primary_address_id = primary_address.id
        @agency.save!
        # @agency.primary_address = Address.create(address_params)
      end
      return render json: @agency.primary_address
    end

    private

    def address_params
      params.require(:address).permit(:street_address, :postal_code, :city, :region, :country, :longitude, :latitude)
    end


    def agency_params
      params.require(:agency).permit(:company_name, :display_name, :phone_number_primary, :phone_number_other)
    end

  end
end
