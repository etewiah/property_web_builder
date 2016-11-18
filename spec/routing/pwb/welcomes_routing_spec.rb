require "rails_helper"

module Pwb
  RSpec.describe WelcomeController, type: :routing do
    describe "routing" do

      it "routes to #index" do
        expect(:get => "/welcomes").to route_to("welcomes#index")
      end

      it "routes to #new" do
        expect(:get => "/welcomes/new").to route_to("welcomes#new")
      end

      it "routes to #show" do
        expect(:get => "/welcomes/1").to route_to("welcomes#show", :id => "1")
      end

      it "routes to #edit" do
        expect(:get => "/welcomes/1/edit").to route_to("welcomes#edit", :id => "1")
      end

      it "routes to #create" do
        expect(:post => "/welcomes").to route_to("welcomes#create")
      end

      it "routes to #update via PUT" do
        expect(:put => "/welcomes/1").to route_to("welcomes#update", :id => "1")
      end

      it "routes to #update via PATCH" do
        expect(:patch => "/welcomes/1").to route_to("welcomes#update", :id => "1")
      end

      it "routes to #destroy" do
        expect(:delete => "/welcomes/1").to route_to("welcomes#destroy", :id => "1")
      end

    end
  end
end
