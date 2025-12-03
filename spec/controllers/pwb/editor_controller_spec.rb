require 'rails_helper'

module Pwb
  RSpec.describe EditorController, type: :controller do
    # routes { Pwb::Engine.routes }

    let(:admin_user) { FactoryBot.create(:pwb_user, :admin) }
    let(:regular_user) { FactoryBot.create(:pwb_user) }

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
          allow(controller).to receive(:current_user).and_return(regular_user)
        end

        it "redirects to root" do
          get :show
          expect(response).to redirect_to(root_path)
        end
      end

      context "when user is admin" do
        before do
          allow(controller).to receive(:current_user).and_return(admin_user)
        end

        it "renders the show template" do
          get :show
          expect(response).to render_template(:show)
        end

        it "assigns default iframe path as root" do
          get :show
          expect(assigns(:iframe_path)).to include("/")
        end

        it "assigns custom iframe path when provided" do
          get :show, params: { path: "contact-us" }
          expect(assigns(:iframe_path)).to eq("/contact-us")
        end

        it "prepends slash to path if missing" do
          get :show, params: { path: "about-us" }
          expect(assigns(:iframe_path)).to eq("/about-us")
        end
      end
    end
  end
end
