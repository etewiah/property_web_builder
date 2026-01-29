# frozen_string_literal: true

require 'rails_helper'

module ApiManage
  module V1
    RSpec.describe "PagePartReorder", type: :request do
      let(:website) { FactoryBot.create(:pwb_website, subdomain: 'reorder-test') }
      let!(:page) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page, slug: 'home', website: website)
        end
      end
      let!(:page_content1) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_content,
                            page: page,
                            page_part_key: "heroes/hero_centered",
                            sort_order: 0,
                            website: website)
        end
      end
      let!(:page_content2) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_content,
                            page: page,
                            page_part_key: "cta/cta_banner",
                            sort_order: 1,
                            website: website)
        end
      end
      let!(:page_content3) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_content,
                            page: page,
                            page_part_key: "features/feature_grid",
                            sort_order: 2,
                            website: website)
        end
      end

      before do
        Pwb::Current.reset
        allow(Pwb::Current).to receive(:website).and_return(website)
        host! "#{website.subdomain}.test.host"
      end

      describe "PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/reorder" do
        it "reorders page parts using semantic identifiers" do
          # Initial order: hero (0), cta (1), features (2)
          expect(page_content1.sort_order).to eq(0)
          expect(page_content2.sort_order).to eq(1)
          expect(page_content3.sort_order).to eq(2)

          # Reorder to: features, hero, cta
          patch "/api_manage/v1/en/pages/home/page_parts/reorder",
                params: {
                  order: [
                    "features/feature_grid",
                    "heroes/hero_centered",
                    "cta/cta_banner"
                  ]
                },
                as: :json

          expect(response).to have_http_status(:success)
          json = JSON.parse(response.body)

          expect(json['page_slug']).to eq('home')
          expect(json['order']).to eq([
            "features/feature_grid",
            "heroes/hero_centered",
            "cta/cta_banner"
          ])
          expect(json['message']).to eq('Page parts reordered successfully')

          # Verify database was updated
          page_content1.reload
          page_content2.reload
          page_content3.reload

          expect(page_content3.sort_order).to eq(0) # features now first
          expect(page_content1.sort_order).to eq(1) # hero now second
          expect(page_content2.sort_order).to eq(2) # cta now third
        end

        it "handles URL-encoded page_part_keys" do
          patch "/api_manage/v1/en/pages/home/page_parts/reorder",
                params: {
                  order: [
                    "cta/cta_banner",
                    "features/feature_grid",
                    "heroes/hero_centered"
                  ]
                },
                as: :json

          expect(response).to have_http_status(:success)
        end

        it "returns error when order parameter is missing" do
          patch "/api_manage/v1/en/pages/home/page_parts/reorder",
                params: {},
                as: :json

          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Missing parameter')
        end

        it "returns error when order is not an array" do
          patch "/api_manage/v1/en/pages/home/page_parts/reorder",
                params: { order: "heroes/hero_centered" },
                as: :json

          expect(response).to have_http_status(:bad_request)
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Missing parameter')
        end

        it "returns 404 for non-existent page" do
          patch "/api_manage/v1/en/pages/non-existent/page_parts/reorder",
                params: { order: ["heroes/hero_centered"] },
                as: :json

          expect(response).to have_http_status(:not_found)
          json = JSON.parse(response.body)
          expect(json['code']).to eq('PAGE_NOT_FOUND')
        end

        it "returns error for unknown page_part_keys" do
          patch "/api_manage/v1/en/pages/home/page_parts/reorder",
                params: {
                  order: [
                    "heroes/hero_centered",
                    "unknown/part",
                    "another/missing"
                  ]
                },
                as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json['code']).to eq('PAGE_PARTS_NOT_FOUND')
          expect(json['unknown_keys']).to contain_exactly('unknown/part', 'another/missing')
          expect(json['available_keys']).to include('heroes/hero_centered')
        end

        it "allows partial reorder (subset of page parts)" do
          # Only reorder 2 of 3 parts - the third keeps its position
          patch "/api_manage/v1/en/pages/home/page_parts/reorder",
                params: {
                  order: [
                    "cta/cta_banner",
                    "heroes/hero_centered"
                  ]
                },
                as: :json

          expect(response).to have_http_status(:success)

          page_content1.reload
          page_content2.reload

          expect(page_content2.sort_order).to eq(0) # cta now first
          expect(page_content1.sort_order).to eq(1) # hero now second
          # page_content3 (features) keeps sort_order: 2
        end
      end
    end
  end
end
