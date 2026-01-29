# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::Pages", type: :request do
  let!(:website) { FactoryBot.create(:pwb_website, subdomain: "pages-test") }
  let!(:page) do
    ActsAsTenant.with_tenant(website) do
      FactoryBot.create(:pwb_page, slug: "about-us", website: website)
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

  describe "GET /api_public/v1/pages/:id" do
    it "returns the page" do
      get "/api_public/v1/pages/#{page.id}"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["id"]).to eq(page.id)
    end

    context "when page does not exist" do
      it "returns a descriptive error message" do
        get "/api_public/v1/pages/99999"
        expect(response).to have_http_status(404)
        json = response.parsed_body
        expect(json.dig("error", "code")).to eq("PAGE_NOT_FOUND")
        expect(json.dig("error", "message")).to include("No page exists with id '99999'")
        expect(json.dig("error", "status")).to eq(404)
      end
    end
  end

  # DEPRECATED: This endpoint has been replaced by /localized_page/by_slug/:slug
  # and /liquid_page/by_slug/:slug - see localized_pages_spec.rb and liquid_pages_spec.rb
  describe "GET /api_public/v1/pages/by_slug/:slug", skip: "Deprecated: use localized_page or liquid_page endpoints instead" do
    it "returns the page by slug" do
      get "/api_public/v1/pages/by_slug/about-us"
      expect(response).to have_http_status(200)
      json = response.parsed_body
      expect(json["slug"]).to eq("about-us")
    end

    context "when page does not exist" do
      it "returns a descriptive error message with available pages" do
        get "/api_public/v1/pages/by_slug/nonexistent-page"
        expect(response).to have_http_status(404)
        json = response.parsed_body
        expect(json.dig("error", "code")).to eq("PAGE_NOT_FOUND")
        expect(json.dig("error", "message")).to include("No page exists with slug 'nonexistent-page'")
        expect(json.dig("error", "message")).to include("about-us")
        expect(json.dig("error", "status")).to eq(404)
      end
    end
  end

  # DEPRECATED: Tests for include_rendered on pages/by_slug endpoint
  # See localized_pages_spec.rb for tests on the current endpoint
  describe "include_rendered parameter", skip: "Deprecated: use localized_page endpoint instead" do
    let!(:page_with_content) do
      ActsAsTenant.with_tenant(website) do
        page = FactoryBot.create(:pwb_page, slug: "home", website: website)
        # Create page content with rendered HTML
        # Content.raw uses Mobility, so we need to set it with locale context
        content = Pwb::Content.create!(
          website: website,
          page_part_key: "heroes/hero_centered"
        )
        Mobility.with_locale(:en) do
          content.raw = "<section class='hero'><h1>Welcome</h1></section>"
          content.save!
        end
        Pwb::PageContent.create!(
          page: page,
          website: website,
          content: content,
          page_part_key: "heroes/hero_centered",
          sort_order: 1,
          visible_on_page: true,
          is_rails_part: false
        )
        # Create a Rails part (no pre-rendered HTML)
        Pwb::PageContent.create!(
          page: page,
          website: website,
          page_part_key: "properties/featured",
          sort_order: 2,
          visible_on_page: true,
          is_rails_part: true
        )
        page
      end
    end

    it "returns rendered HTML for page contents when include_rendered=true" do
      get "/api_public/v1/pages/by_slug/home", params: { include_rendered: "true" }
      expect(response).to have_http_status(200)
      json = response.parsed_body

      expect(json["page_contents"]).to be_an(Array)
      expect(json["page_contents"].length).to eq(2)

      # First content: Liquid-rendered HTML
      hero_content = json["page_contents"].find { |c| c["page_part_key"] == "heroes/hero_centered" }
      expect(hero_content["is_rails_part"]).to be false
      expect(hero_content["rendered_html"]).to include("<section class='hero'>")
      expect(hero_content["rendered_html"]).to include("<h1>Welcome</h1>")

      # Second content: Rails part (no HTML)
      rails_content = json["page_contents"].find { |c| c["page_part_key"] == "properties/featured" }
      expect(rails_content["is_rails_part"]).to be true
      expect(rails_content["rendered_html"]).to be_nil
    end

    it "does not include page_contents when include_rendered is not specified" do
      get "/api_public/v1/pages/by_slug/home"
      expect(response).to have_http_status(200)
      json = response.parsed_body

      expect(json["page_contents"]).to be_nil
    end

    context "with non-default locale" do
      it "localizes URLs in rendered HTML" do
        # Create content with a link that should be localized
        # Content.raw uses Mobility, so we need to set it with locale context
        ActsAsTenant.with_tenant(website) do
          content = page_with_content.page_contents.first.content
          Mobility.with_locale(:en) do
            content.raw = '<a href="/search/buy">Search</a>'
          end
          Mobility.with_locale(:es) do
            content.raw = '<a href="/search/buy">Buscar</a>'
          end
          content.save!
        end

        I18n.with_locale(:es) do
          get "/api_public/v1/pages/by_slug/home", params: { include_rendered: "true", locale: "es" }
          expect(response).to have_http_status(200)
          json = response.parsed_body

          hero_content = json["page_contents"].find { |c| c["page_part_key"] == "heroes/hero_centered" }
          # URL should be localized to /es/search/buy
          expect(hero_content["rendered_html"]).to include('href="/es/search/buy"')
        end
      end
    end
  end

  describe "website not provisioned errors" do
    context "when website has no pages" do
      before do
        # Remove all pages from the website to simulate unprovisioned state
        website.pages.destroy_all
      end

      it "returns website not provisioned error for show action" do
        get "/api_public/v1/pages/1"
        expect(response).to have_http_status(404)
        json = response.parsed_body
        expect(json["error"]).to eq("Website not provisioned")
        expect(json["message"]).to include("has not been provisioned")
        expect(json["code"]).to eq("WEBSITE_NOT_PROVISIONED")
      end

      # DEPRECATED: by_slug endpoint replaced by localized_page
      it "returns website not provisioned error for show_by_slug action", skip: "Deprecated endpoint" do
        get "/api_public/v1/pages/by_slug/home"
        expect(response).to have_http_status(404)
        json = response.parsed_body
        expect(json["error"]).to eq("Website not provisioned")
        expect(json["message"]).to include("has not been provisioned")
        expect(json["message"]).to include("setup/seeding process")
        expect(json["code"]).to eq("WEBSITE_NOT_PROVISIONED")
      end
    end
  end
end
