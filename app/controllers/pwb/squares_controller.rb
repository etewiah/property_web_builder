require_dependency "pwb/application_controller"

module Pwb
  class SquaresController < ActionController::Base
    layout 'pwb/squares'

    def show_prop
      fb_instance_id = Rails.application.credentials.fb_instance_id
      base_uri = "https://#{fb_instance_id}.firebaseio.com/"
      firebase = Firebase::Client.new(base_uri)
      @client_key = params["client_id"]
      @prop_key = params["prop_id"]
      response = firebase.get("props/" + @client_key + "/" + @prop_key )

      @prop = response.body
      # byebug
      # push("todos", { :name => 'Pick the milk', :priority => 1 })
      # response.success? # => true
      # response.code # => 200
      # response.body # => { 'name' => "-INOQPH-aV_psbk3ZXEX" }
      # response.raw_body # => '{"name":"-INOQPH-aV_psbk3ZXEX"}'

      render 'pwb/squares/show_prop'
    end

    def show_client
      fb_instance_id = Rails.application.credentials.fb_instance_id
      base_uri = "https://#{fb_instance_id}.firebaseio.com/"
      firebase = Firebase::Client.new(base_uri)
      @client_key = params["client_id"]
      response = firebase.get("props/" + @client_key )

      @props_hash = response.body
      # byebug
      # push("todos", { :name => 'Pick the milk', :priority => 1 })
      # response.success? # => true
      # response.code # => 200
      # response.body # => { 'name' => "-INOQPH-aV_psbk3ZXEX" }
      # response.raw_body # => '{"name":"-INOQPH-aV_psbk3ZXEX"}'

      render 'pwb/squares/show_client'
    end

    private
  end
end
