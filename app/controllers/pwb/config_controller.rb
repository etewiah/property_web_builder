require_dependency "pwb/application_controller"

module Pwb
  class ConfigController < ActionController::Base
    layout 'pwb/config'

    def show
      render 'pwb/config/show'
    end

    def show_client
      fb_instance_id = Rails.application.secrets.fb_instance_id
      base_uri = "https://#{fb_instance_id}.firebaseio.com/"
      firebase = Firebase::Client.new(base_uri)
      @client_key = params["client_id"]
      response = firebase.get("props/" + @client_key )

      @props_hash = response.body
      render 'pwb/config/show_client'
    end

    private


  end
end
