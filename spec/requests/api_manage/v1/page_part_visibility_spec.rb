# frozen_string_literal: true

require 'rails_helper'

module ApiManage
  module V1
    RSpec.describe "PagePartVisibility", type: :request do
      let(:website) { FactoryBot.create(:pwb_website, subdomain: 'visibility-test') }
      let!(:page) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page, slug: 'about-us', website: website)
        end
      end
      let!(:page_content) do
        ActsAsTenant.with_tenant(website) do
          content = FactoryBot.create(:pwb_content,
                                      page_part_key: "heroes/hero_centered",
                                      website: website)
          FactoryBot.create(:pwb_page_content,
                            page: page,
                            content: content,
                            page_part_key: "heroes/hero_centered",
                            visible_on_page: true,
                            sort_order: 1,
                            website: website)
        end
      end

      before do
        Pwb::Current.reset
        allow(Pwb::Current).to receive(:website).and_return(website)
        host! "#{website.subdomain}.test.host"
      end

      describe "PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key/visibility" do
        it "hides a visible page part" do
          expect(page_content.visible_on_page).to be true

          patch "/api_manage/v1/en/pages/about-us/page_parts/heroes%2Fhero_centered/visibility",
                params: { visible: false },
                as: :json

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)

          expect(json['visible']).to be false
          expect(json['page_slug']).to eq('about-us')
          expect(json['page_part_key']).to eq('heroes/hero_centered')

          page_content.reload
          expect(page_content.visible_on_page).to be false
        end

        it "shows a hidden page part" do
          page_content.update!(visible_on_page: false)

          patch "/api_manage/v1/en/pages/about-us/page_parts/heroes%2Fhero_centered/visibility",
                params: { visible: true },
                as: :json

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)

          expect(json['visible']).to be true

          page_content.reload
          expect(page_content.visible_on_page).to be true
        end

        it "accepts string 'true' and 'false' values" do
          patch "/api_manage/v1/en/pages/about-us/page_parts/heroes%2Fhero_centered/visibility",
                params: { visible: "false" },
                as: :json

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)
          expect(json['visible']).to be false
        end

        it "returns error when visible parameter is missing" do
          patch "/api_manage/v1/en/pages/about-us/page_parts/heroes%2Fhero_centered/visibility",
                params: {},
                as: :json

          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Missing parameter')
        end

        it "returns 404 for non-existent page" do
          patch "/api_manage/v1/en/pages/non-existent/page_parts/heroes%2Fhero_centered/visibility",
                params: { visible: false },
                as: :json

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json['code']).to eq('PAGE_NOT_FOUND')
        end

        it "returns 404 for non-existent page part" do
          patch "/api_manage/v1/en/pages/about-us/page_parts/non_existent_part/visibility",
                params: { visible: false },
                as: :json

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json['code']).to eq('PAGE_PART_NOT_FOUND')
          expect(json['available_parts']).to include('heroes/hero_centered')
        end
      end
    end
  end
end
