# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe EditorController, type: :controller do
    let!(:website) { FactoryBot.create(:pwb_website) }
    let(:admin_user) { FactoryBot.create(:pwb_user, :admin, website: website) }
    let(:regular_user) { FactoryBot.create(:pwb_user, website: website) }

    before do
      @request.env["devise.mapping"] = ::Devise.mappings[:user]
    end

    describe "GET #show" do
      context "when user is not logged in" do
        it "redirects to root" do
          get :show
          expect(response).to redirect_to(root_path)
        end
      end

      context "when user is logged in but not admin" do
        before do
          sign_in regular_user, scope: :user
        end

        it "redirects to root" do
          get :show
          expect(response).to redirect_to(root_path)
        end
      end

      context "when user is admin" do
        before do
          sign_in admin_user, scope: :user
        end

        it "renders the show template" do
          get :show
          expect(response).to render_template(:show)
        end

        it "assigns default iframe path as root" do
          get :show
          expect(assigns(:iframe_path)).to include("/")
        end

        it "assigns custom iframe path when provided with edit_mode param" do
          get :show, params: { path: "contact-us" }
          expect(assigns(:iframe_path)).to eq("/contact-us?edit_mode=true")
        end

        it "prepends slash to path if missing and includes edit_mode" do
          get :show, params: { path: "about-us" }
          expect(assigns(:iframe_path)).to eq("/about-us?edit_mode=true")
        end
      end
    end
  end
end
