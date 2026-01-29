# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiManage::V1::PageParts", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website, subdomain: "manage-parts-test") }
  let!(:page) do
    ActsAsTenant.with_tenant(website) do
      FactoryBot.create(:pwb_page, slug: "test-page", website: website)
    end
  end

  let!(:page_part) do
    ActsAsTenant.with_tenant(website) do
      Pwb::PagePart.create!(
        website_id: website.id,
        page_part_key: "heroes/hero_centered",
        page_slug: page.slug,
        show_in_editor: true,
        block_contents: {
          "en" => {
            "blocks" => {
              "title" => { "content" => "Original Title" },
              "subtitle" => { "content" => "Original Subtitle" }
            }
          }
        }
      )
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

  describe "GET /api_manage/v1/:locale/page_parts" do
    it "returns list of page parts" do
      get "/api_manage/v1/en/page_parts"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["page_parts"]).to be_an(Array)
      expect(json["page_parts"].first["page_part_key"]).to eq("heroes/hero_centered")
    end

    it "filters by page_slug" do
      get "/api_manage/v1/en/page_parts", params: { page_slug: page.slug }
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["page_parts"].length).to eq(1)
    end
  end

  describe "GET /api_manage/v1/:locale/page_parts/:id" do
    it "returns page part details" do
      get "/api_manage/v1/en/page_parts/#{page_part.id}"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["page_part"]["id"]).to eq(page_part.id)
      expect(json["page_part"]["page_part_key"]).to eq("heroes/hero_centered")
      expect(json["page_part"]["block_contents"]["blocks"]["title"]["content"]).to eq("Original Title")
    end

    it "includes field_schema" do
      get "/api_manage/v1/en/page_parts/#{page_part.id}"
      json = response.parsed_body
      expect(json["page_part"]["field_schema"]).to be_present
      expect(json["page_part"]["field_schema"]["fields"]).to be_an(Array)
    end
  end

  describe "GET /api_manage/v1/:locale/page_parts/by_key/:key" do
    it "returns page part by composite key" do
      key = "#{page.slug}::heroes/hero_centered"
      get "/api_manage/v1/en/page_parts/by_key/#{CGI.escape(key)}"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["page_part"]["page_part_key"]).to eq("heroes/hero_centered")
      expect(json["page_part"]["page_slug"]).to eq(page.slug)
    end

    it "auto-creates page part if not exists" do
      new_key = "#{page.slug}::cta/cta_banner"
      expect {
        get "/api_manage/v1/en/page_parts/by_key/#{CGI.escape(new_key)}"
      }.to change(Pwb::PagePart, :count).by(1)

      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["page_part"]["page_part_key"]).to eq("cta/cta_banner")
    end
  end

  # DEPRECATED: update action removed from routes
  # Use instead: PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key
  # See page_part_content_spec.rb for tests
  describe "PATCH /api_manage/v1/:locale/page_parts/:id", skip: "Deprecated: use page_part_content endpoint" do
    it "updates block_contents" do
      patch "/api_manage/v1/en/page_parts/#{page_part.id}",
        params: {
          block_contents: {
            title: { content: "Updated Title" },
            subtitle: { content: "Updated Subtitle" }
          },
          regenerate: false
        }

      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["page_part"]["block_contents"]["blocks"]["title"]["content"]).to eq("Updated Title")
      expect(json["page_part"]["block_contents"]["blocks"]["subtitle"]["content"]).to eq("Updated Subtitle")

      # Verify persisted
      page_part.reload
      expect(page_part.block_contents.dig("en", "blocks", "title", "content")).to eq("Updated Title")
    end

    it "preserves other locale content when updating one locale" do
      # Add Spanish content
      page_part.update!(
        block_contents: page_part.block_contents.merge(
          "es" => { "blocks" => { "title" => { "content" => "Título en Español" } } }
        )
      )

      patch "/api_manage/v1/en/page_parts/#{page_part.id}",
        params: {
          block_contents: { title: { content: "New English Title" } },
          regenerate: false
        }

      expect(response).to have_http_status(200)

      page_part.reload
      expect(page_part.block_contents.dig("en", "blocks", "title", "content")).to eq("New English Title")
      expect(page_part.block_contents.dig("es", "blocks", "title", "content")).to eq("Título en Español")
    end
  end

  # DEPRECATED: update_by_key action removed from routes
  # Use instead: PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key
  # See page_part_content_spec.rb for tests
  describe "PATCH /api_manage/v1/:locale/page_parts/by_key/:key", skip: "Deprecated: use page_part_content endpoint" do
    it "updates page part by composite key" do
      key = "#{page.slug}::heroes/hero_centered"
      patch "/api_manage/v1/en/page_parts/by_key/#{CGI.escape(key)}",
        params: {
          block_contents: { title: { content: "Key Updated Title" } },
          regenerate: false
        }

      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["page_part"]["block_contents"]["blocks"]["title"]["content"]).to eq("Key Updated Title")
    end
  end

  describe "POST /api_manage/v1/:locale/page_parts/:id/regenerate" do
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

    it "regenerates pre-rendered HTML" do
      post "/api_manage/v1/en/page_parts/#{page_part.id}/regenerate"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["message"]).to include("regenerated")
    end
  end
end
