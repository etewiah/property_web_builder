require "rails_helper"

module Pwb
  RSpec.describe "PropertyWebBuilder routing ", type: :routing do
    routes { Pwb::Engine.routes }
    describe "root url" do
      it "routes to welcome_controller#index" do
        expect({
                 get: "/"
        }).to route_to(
          controller: "pwb/welcome",
          action: "index"
        )
      end
    end
    describe "welcome routing" do

      it "routes to #index" do
        expect(:get => "/welcome").to route_to("pwb/welcome#index")
      end

      # it "routes to #new" do
      #   expect(:get => "/welcome/new").to route_to("welcome#new")
      # end

      # it "routes to #show" do
      #   expect(:get => "/welcome/1").to route_to("welcome#show", :id => "1")
      # end

      # it "routes to #edit" do
      #   expect(:get => "/welcome/1/edit").to route_to("welcome#edit", :id => "1")
      # end

      # it "routes to #create" do
      #   expect(:post => "/welcome").to route_to("welcome#create")
      # end

      # it "routes to #update via PUT" do
      #   expect(:put => "/welcome/1").to route_to("welcome#update", :id => "1")
      # end

      # it "routes to #update via PATCH" do
      #   expect(:patch => "/welcome/1").to route_to("welcome#update", :id => "1")
      # end

      # it "routes to #destroy" do
      #   expect(:delete => "/welcome/1").to route_to("welcome#destroy", :id => "1")
      # end

    end
  end
end
