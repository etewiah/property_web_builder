require 'rails_helper'

module Pwb
  RSpec.describe FirebaseLoginController, type: :controller do
    routes { Rails.application.routes }
    
    let(:website) { FactoryBot.create(:pwb_website) }
    
    before do
      # Set up website context for all tests
      allow(controller).to receive(:current_website_from_subdomain).and_return(website)
      allow(Pwb::Current).to receive(:website).and_return(website)
    end

    describe "GET #index" do
      it "renders the index template" do
        get :index
        expect(response).to render_template("pwb/firebase_login/index")
      end
    end

    describe "GET #forgot_password" do
      it "renders the forgot_password template" do
        get :forgot_password
        expect(response).to render_template("pwb/firebase_login/forgot_password")
      end
    end

    describe "GET #sign_up" do
      it "renders the sign_up template" do
        get :sign_up
        expect(response).to render_template("pwb/firebase_login/sign_up")
      end
    end

    describe "GET #change_password" do
      context "when user is not authenticated" do
        it "redirects to login" do
          get :change_password
          expect(response).to redirect_to("/firebase_login")
        end
      end

      context "when user is authenticated" do
        let(:user) { FactoryBot.create(:pwb_user, website: website) }

        before do
          sign_in user
        end

        it "renders the change_password template" do
          get :change_password
          expect(response).to render_template("pwb/firebase_login/change_password")
        end
      end
    end
  end
end
