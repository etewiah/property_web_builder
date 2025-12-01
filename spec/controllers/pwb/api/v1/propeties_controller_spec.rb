require "rails_helper"

module Pwb
  RSpec.describe Api::V1::PropertiesController, type: :controller do
    routes { Rails.application.routes }
    context "with admin user" do
      login_admin_user

      # describe "bulk create" do
      #   it "creates multiple properties" do
      #     bulk_create_input = File.read(File.join(RSpec.configuration.fixture_paths.first, "params/bulk_create.json"))
      #     bulk_create_params = {
      #       propertiesJSON: bulk_create_input,
      #     }

      #     expect {
      #       post :bulk_create, params: bulk_create_params
      #     }.to change(Prop, :count).by(4)
      #     expect(response.status).to eq(200)
      #   end
      # end
    end
  end
end
