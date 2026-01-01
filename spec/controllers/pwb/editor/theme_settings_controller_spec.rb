# frozen_string_literal: true

require 'rails_helper'

module Pwb
  RSpec.describe Editor::ThemeSettingsController, type: :controller do
    let!(:website) { FactoryBot.create(:pwb_website) }
    let(:admin_user) { FactoryBot.create(:pwb_user, :admin) }

    before do
      @request.env["devise.mapping"] = ::Devise.mappings[:user]
    end

    describe "GET #show" do
      it "returns theme settings as JSON" do
        get :show, format: :json
        expect(response).to have_http_status(:success)
        
        json = JSON.parse(response.body)
        expect(json).to have_key("style_variables")
        expect(json).to have_key("theme_name")
      end

      it "includes default style variables" do
        get :show, format: :json
        json = JSON.parse(response.body)
        
        expect(json["style_variables"]).to have_key("primary_color")
        expect(json["style_variables"]).to have_key("secondary_color")
      end
    end

    describe "PATCH #update" do
      let(:valid_params) do
        {
          style_variables: {
            primary_color: "#ff0000",
            secondary_color: "#00ff00",
            action_color: "#0000ff"
          }
        }
      end

      it "updates the style variables" do
        patch :update, params: valid_params, format: :json
        expect(response).to have_http_status(:success)
        
        json = JSON.parse(response.body)
        expect(json["status"]).to eq("success")
        # style_variables includes custom and palette colors; check custom was stored
        expect(json["style_variables"]).to include("primary_color")
        # Verify the raw stored value
        website.reload
        expect(website.style_variables_for_theme['default']['primary_color']).to eq("#ff0000")
      end

      it "merges with existing style variables" do
        # Set initial values via the controller
        # Using body_style and theme which are NOT in the palette colors
        patch :update, params: { style_variables: { primary_color: "#111111", body_style: "siteLayout.boxed", theme: "dark" } }, format: :json
        expect(response).to have_http_status(:success)

        # Update only primary_color
        patch :update, params: { style_variables: { primary_color: "#333333" } }, format: :json

        json = JSON.parse(response.body)
        expect(response).to have_http_status(:success)

        # Verify raw stored values
        website.reload
        expect(website.style_variables_for_theme['default']['primary_color']).to eq("#333333")
        # body_style and theme should be preserved (not in palette colors)
        expect(website.style_variables_for_theme['default']['body_style']).to eq("siteLayout.boxed")
        expect(website.style_variables_for_theme['default']['theme']).to eq("dark")
      end

      it "returns success message" do
        patch :update, params: valid_params, format: :json
        json = JSON.parse(response.body)
        
        expect(json["message"]).to eq("Theme settings saved successfully")
      end
    end
  end
end
