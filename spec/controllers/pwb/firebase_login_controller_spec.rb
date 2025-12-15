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

      context "when website is live" do
        before do
          website.update!(provisioning_state: 'live')
        end

        it "does not set require_owner_email" do
          get :sign_up
          expect(assigns(:require_owner_email)).to be_falsey
        end

        it "does not set required_email" do
          get :sign_up
          expect(assigns(:required_email)).to be_nil
        end
      end

      context "when website is locked_pending_registration" do
        let(:owner_email) { "owner@example.com" }

        before do
          website.update!(
            provisioning_state: 'locked_pending_registration',
            owner_email: owner_email
          )
        end

        it "sets require_owner_email to true" do
          get :sign_up
          expect(assigns(:require_owner_email)).to be true
        end

        it "sets required_email to the owner email" do
          get :sign_up
          expect(assigns(:required_email)).to eq(owner_email)
        end

        it "renders the sign_up template" do
          get :sign_up
          expect(response).to render_template("pwb/firebase_login/sign_up")
        end
      end
    end

    describe "GET #change_password" do
      context "when user is not authenticated" do
        it "redirects to login" do
          get :change_password
          expect(response).to redirect_to("/pwb_login")
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
