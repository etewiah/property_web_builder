# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiManage::V1::PageContents", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website, subdomain: "manage-test") }
  let!(:page) do
    ActsAsTenant.with_tenant(website) do
      FactoryBot.create(:pwb_page, slug: "test-page", website: website)
    end
  end

  before(:each) do
    Pwb::Current.reset
    Pwb::Current.website = website
    ActsAsTenant.current_tenant = website
    host! "#{website.subdomain}.example.com"
  end

  after(:each) do
    ActsAsTenant.current_tenant = nil
    Pwb::Current.reset
  end

  describe "GET /api_manage/v1/:locale/pages/:page_id/page_contents" do
    let!(:page_content) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_page_content,
          page: page,
          website: website,
          page_part_key: "heroes/hero_centered",
          sort_order: 1,
          visible_on_page: true
        )
      end
    end

    it "returns page contents for the page" do
      get "/api_manage/v1/en/pages/#{page.id}/page_contents"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["page_contents"]).to be_an(Array)
      expect(json["page_contents"].length).to eq(1)
      expect(json["page_contents"].first["page_part_key"]).to eq("heroes/hero_centered")
    end

    context "with container page content" do
      let!(:container) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_content,
            page: page,
            website: website,
            page_part_key: "layout/layout_two_column_equal",
            sort_order: 2,
            visible_on_page: true
          )
        end
      end

      let!(:child) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_content,
            page: page,
            website: website,
            page_part_key: "cta/cta_banner",
            parent_page_content: container,
            slot_name: "left",
            sort_order: 1,
            visible_on_page: true
          )
        end
      end

      it "returns containers with slots structure" do
        get "/api_manage/v1/en/pages/#{page.id}/page_contents"
        expect(response).to have_http_status(200)
        json = response.parsed_body

        # Should only return root-level page contents
        root_contents = json["page_contents"]
        expect(root_contents.length).to eq(2) # hero and container, not child

        container_json = root_contents.find { |pc| pc["is_container"] }
        expect(container_json).to be_present
        expect(container_json["slots"]).to be_a(Hash)
        expect(container_json["slots"]["left"]).to be_an(Array)
        expect(container_json["slots"]["left"].first["page_part_key"]).to eq("cta/cta_banner")
      end
    end
  end

  describe "POST /api_manage/v1/:locale/pages/:page_id/page_contents" do
    it "creates a new page content" do
      expect {
        post "/api_manage/v1/en/pages/#{page.id}/page_contents",
          params: {
            page_content: {
              page_part_key: "cta/cta_banner",
              sort_order: 1,
              visible_on_page: true
            }
          }
      }.to change(Pwb::PageContent, :count).by(1)

      expect(response).to have_http_status(201)
      json = response.parsed_body
      expect(json["page_content"]["page_part_key"]).to eq("cta/cta_banner")
    end

    context "creating child in container" do
      let!(:container) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_content,
            page: page,
            website: website,
            page_part_key: "layout/layout_two_column_equal",
            sort_order: 1,
            visible_on_page: true
          )
        end
      end

      it "creates child page content in slot" do
        post "/api_manage/v1/en/pages/#{page.id}/page_contents",
          params: {
            page_content: {
              page_part_key: "cta/cta_banner",
              parent_page_content_id: container.id,
              slot_name: "left",
              sort_order: 1,
              visible_on_page: true
            }
          }

        expect(response).to have_http_status(201)
        json = response.parsed_body
        expect(json["page_content"]["parent_page_content_id"]).to eq(container.id)
        expect(json["page_content"]["slot_name"]).to eq("left")
      end

      it "rejects invalid parent (non-container)" do
        non_container = ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_content,
            page: page,
            website: website,
            page_part_key: "cta/cta_banner",
            sort_order: 2,
            visible_on_page: true
          )
        end

        post "/api_manage/v1/en/pages/#{page.id}/page_contents",
          params: {
            page_content: {
              page_part_key: "heroes/hero_centered",
              parent_page_content_id: non_container.id,
              slot_name: "left",
              sort_order: 1,
              visible_on_page: true
            }
          }

        expect(response).to have_http_status(422)
        json = response.parsed_body
        expect(json["error"]).to eq("Invalid parent")
      end
    end
  end

  describe "GET /api_manage/v1/:locale/page_contents/:id" do
    let!(:page_content) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_page_content,
          page: page,
          website: website,
          page_part_key: "heroes/hero_centered",
          sort_order: 1,
          visible_on_page: true
        )
      end
    end

    it "returns page content details" do
      get "/api_manage/v1/en/page_contents/#{page_content.id}"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["page_content"]["id"]).to eq(page_content.id)
      expect(json["page_content"]["page_part_key"]).to eq("heroes/hero_centered")
    end
  end

  describe "PATCH /api_manage/v1/:locale/page_contents/:id" do
    let!(:page_content) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_page_content,
          page: page,
          website: website,
          page_part_key: "heroes/hero_centered",
          sort_order: 1,
          visible_on_page: true
        )
      end
    end

    it "updates page content" do
      patch "/api_manage/v1/en/page_contents/#{page_content.id}",
        params: {
          page_content: {
            visible_on_page: false,
            sort_order: 5
          }
        }

      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["page_content"]["visible_on_page"]).to eq(false)
      expect(json["page_content"]["sort_order"]).to eq(5)
    end
  end

  describe "DELETE /api_manage/v1/:locale/page_contents/:id" do
    let!(:page_content) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_page_content,
          page: page,
          website: website,
          page_part_key: "heroes/hero_centered",
          sort_order: 1,
          visible_on_page: true
        )
      end
    end

    it "deletes page content" do
      expect {
        delete "/api_manage/v1/en/page_contents/#{page_content.id}"
      }.to change(Pwb::PageContent, :count).by(-1)

      expect(response).to have_http_status(200)
    end

    context "with container that has children" do
      let!(:container) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_content,
            page: page,
            website: website,
            page_part_key: "layout/layout_two_column_equal",
            sort_order: 1,
            visible_on_page: true
          )
        end
      end

      let!(:child) do
        ActsAsTenant.with_tenant(website) do
          FactoryBot.create(:pwb_page_content,
            page: page,
            website: website,
            page_part_key: "cta/cta_banner",
            parent_page_content: container,
            slot_name: "left",
            sort_order: 1,
            visible_on_page: true
          )
        end
      end

      it "prevents deletion of container with children" do
        expect {
          delete "/api_manage/v1/en/page_contents/#{container.id}"
        }.not_to change(Pwb::PageContent, :count)

        expect(response).to have_http_status(422)
        json = response.parsed_body
        expect(json["error"]).to eq("Cannot delete")
        expect(json["children_count"]).to eq(1)
      end
    end
  end

  describe "PATCH /api_manage/v1/:locale/pages/:page_id/page_contents/reorder" do
    let!(:pc1) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_page_content, page: page, website: website,
          page_part_key: "heroes/hero_centered", sort_order: 1)
      end
    end
    let!(:pc2) do
      ActsAsTenant.with_tenant(website) do
        FactoryBot.create(:pwb_page_content, page: page, website: website,
          page_part_key: "cta/cta_banner", sort_order: 2)
      end
    end

    it "reorders page contents" do
      patch "/api_manage/v1/en/pages/#{page.id}/page_contents/reorder",
        params: {
          order: [
            { id: pc2.id, sort_order: 1 },
            { id: pc1.id, sort_order: 2 }
          ]
        }

      expect(response).to have_http_status(200)
      expect(pc1.reload.sort_order).to eq(2)
      expect(pc2.reload.sort_order).to eq(1)
    end
  end
end
