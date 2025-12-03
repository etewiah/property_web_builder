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
        expect(json["style_variables"]["primary_color"]).to eq("#ff0000")
      end

      it "merges with existing style variables" do
        # First, set some initial values
        website.style_variables = { "primary_color" => "#111111", "action_color" => "#222222" }
        website.save!

        # Update only primary_color
        patch :update, params: { style_variables: { primary_color: "#333333" } }, format: :json
        
        json = JSON.parse(response.body)
        expect(json["style_variables"]["primary_color"]).to eq("#333333")
        # action_color should be preserved
        expect(json["style_variables"]["action_color"]).to eq("#222222")
      end

      it "returns success message" do
        patch :update, params: valid_params, format: :json
        json = JSON.parse(response.body)
        
        expect(json["message"]).to eq("Theme settings saved successfully")
      end
    end
  end
end
