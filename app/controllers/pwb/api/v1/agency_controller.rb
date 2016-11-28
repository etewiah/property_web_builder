require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::AgencyController < ApplicationController

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

    # def update
    #   @agency = {}
    #   if request.subdomain.present?
    #     @tenant = Tenant.get_from_subdomain(request.subdomain.downcase)
    #     @agency = @tenant ? @tenant.agency : nil
    #     if @agency
    #       @agency.update(agency_params)
    #       # http://patshaughnessy.net/2014/6/16/a-rule-of-thumb-for-strong-parameters
    #       # adding :social_media to the list permitted by strong params does not work so doing below
    #       # which is  ugly but works
    #       @agency.social_media = params[:agency][:social_media]
    #       @agency.save!
    #     end
    #   end
    #   return render json: @agency
    # end

    private

    def agency_params
      params.require(:agency).permit(:company_name, :display_name, :phone_number_primary, :phone_number_other)
    end

  end
end
