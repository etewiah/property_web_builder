require 'rails_helper'

module Pwb
  RSpec.describe WelcomeController, type: :controller do
    routes { Pwb::Engine.routes }
    # This should return the minimal set of attributes required to create a valid
    # Welcome. As you add validations to Welcome, be sure to
    # adjust the attributes here as well.

    let(:valid_attributes) {
      # skip("Add a hash of attributes valid for your model")
      {
        "tag" => "landing-carousel"
      }
    }

    let(:invalid_attributes) {
      skip("Add a hash of attributes invalid for your model")
    }

    # This should return the minimal set of values that should be in the session
    # in order to pass any filters (e.g. authentication) defined in
    # WelcomesController. Be sure to keep this updated too.
    let(:valid_session) { {} }

    describe "GET #index" do
      it "assigns all welcomes as @welcomes" do
        welcome = Content.create! valid_attributes
        # byebug
        get :index, params: {}, session: valid_session
        expect(assigns(:welcomes)).to eq([welcome])
      end
    end

    # describe "GET #show" do
    #   it "assigns the requested welcome as @welcome" do
    #     welcome = Welcome.create! valid_attributes
    #     get :show, params: {id: welcome.to_param}, session: valid_session
    #     expect(assigns(:welcome)).to eq(welcome)
    #   end
    # end

    # describe "GET #new" do
    #   it "assigns a new welcome as @welcome" do
    #     get :new, params: {}, session: valid_session
    #     byebug
    #     expect(assigns(:welcome)).to be_a_new(Welcome)
    #   end
    # end

    # describe "GET #edit" do
    #   it "assigns the requested welcome as @welcome" do
    #     welcome = Welcome.create! valid_attributes
    #     get :edit, params: {id: welcome.to_param}, session: valid_session
    #     expect(assigns(:welcome)).to eq(welcome)
    #   end
    # end


  end
end
