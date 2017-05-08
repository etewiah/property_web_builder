require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::WebsiteController < ApplicationApiController
    # protect_from_forgery with: :null_session

    def update
      @website = Website.unique_instance
      if @website
        @website.update(website_params)
        # http://patshaughnessy.net/2014/6/16/a-rule-of-thumb-for-strong-parameters
        # adding :social_media to the list permitted by strong params does not work so doing below
        # which is  ugly but works
        @website.social_media = params[:website][:social_media]
        @website.style_variables = params[:website][:style_variables]
        @website.save!
      end
      render json: @website
    end

    private

    def website_params
      params.require(:website).permit(
        :company_name, :display_name, :default_area_unit,
        :phone_number_primary, :phone_number_other,
        :theme_name, :default_currency, :default_client_locale,
      supported_locales: []
)
    end
  end
end
