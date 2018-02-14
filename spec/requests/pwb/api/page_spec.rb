require 'rails_helper'

module Pwb
  RSpec.describe 'api/v1/pages request' do

    before(:all) do
      @page = Pwb::Page.find_by_slug "home"
      unless @page.present?
        @page = FactoryGirl.create(:page_with_content_html_page_part, slug: "home")
      end

      @admin_user = User.create!(email: "user@example.org", password: "very-secret", admin: true)
    end

    context 'with signed in admin user' do
      before do
        sign_in @admin_user
      end


      it 'sets page_part visibility correctly' do
        target_page_content = @page.page_contents.find_by_page_part_key "content_html"
        put "/api/v1/pages/page_part_visibility", params: {
          page_slug:"home",
          cmd:"setAsHidden",
          page_part_key:"content_html"
        }
        target_page_content.reload
        expect(response).to be_success
        # expect(response_body_as_json["visible"]).to eq(false)
        expect(target_page_content.visible_on_page).to eq(false)

        put "/api/v1/pages/page_part_visibility", params: {
          page_slug:"home",
          cmd:"setAsVisible",
          page_part_key:"content_html"
        }

        target_page_content.reload
        expect(response).to be_success
        expect(target_page_content.visible_on_page).to eq(true)
        # expect(@prop_for_long_term_rent.features.find_by(feature_key: "aireAcondicionado")).to be_present
        # expect(@prop_for_long_term_rent.features.count).to eq(1)
        # expect(response_body_as_json[0]["feature_key"]).to eq("aireAcondicionado")
        # expect(response.body).to have_json_path("feature_key")
      end

    end

    context 'without signed in admin user' do
      it 'redirects to sign_in page' do
        sign_out @admin_user

        get "/api/v1/pages/home"
        expect(response.status).to eq(302)
      end
    end

    after(:all) do
      # @prop_for_sale.destroy
      # @admin_user.destroy
    end
  end
end
