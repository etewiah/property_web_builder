require "rails_helper"

module Pwb
  RSpec.describe Api::V1::AgencyController, type: :controller do
    routes { Rails.application.routes }

    before(:each) do
      # Ensure a website exists for all specs
      FactoryBot.create(:pwb_website) unless Pwb::Website.first
    end

    context "without signing in" do
      before(:each) do
        sign_in_stub nil
      end
      it "should not have a current_user" do
        expect(controller.current_user).to eq(nil)
      end
    end

    context "with non_admin user" do
      login_non_admin_user

      it "should have a current_user" do
        expect(controller.current_user).to_not eq(nil)
      end

      describe "GET #show" do
        it "returns unauthorized status" do
          get :show

          expect(response.status).to eq(422)
        end
      end
    end

    context "with admin user" do
      login_admin_user

      it "should have a current_user" do
        expect(controller.current_user).to_not eq(nil)
      end

      describe "GET #show" do
        before do
          # Update the first website's agency with the expected company name
          website = Pwb::Website.first
          website.agency.update!(company_name: "my re")
        end

        it "returns correct agency and default setup info" do
          get :show
          # , format: :json

          expect(response.status).to eq(200)
          # expect(response.content_type).to eq("application/json")

          result = JSON.parse(response.body)

          expect(result).to have_key("agency")
          expect(result["agency"]["company_name"]).to eq("my re")
          expect(result["setup"]["name"]).to eq("default")
        end
      end
    end
  end
end
