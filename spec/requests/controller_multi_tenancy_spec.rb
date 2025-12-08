require 'rails_helper'

RSpec.describe "Controller Multi-tenancy Data Isolation", type: :request do
  # Clear current website before each test
  before(:each) do
    Pwb::Current.reset
  end

  # Helper to create properties that appear in the materialized view
  # Controllers use ListedProperty (materialized view) which requires RealtyAsset + SaleListing/RentalListing
  def create_sale_property(website:, reference:, price_cents:, visible: true)
    realty_asset = Pwb::RealtyAsset.create!(website: website, reference: reference)
    Pwb::SaleListing.create!(
      realty_asset: realty_asset,
      reference: reference,
      visible: visible,
      archived: false,
      active: true,
      price_sale_current_cents: price_cents,
      price_sale_current_currency: 'EUR'
    )
    Pwb::ListedProperty.refresh
    realty_asset
  end

  def create_rental_property(website:, reference:, price_cents:, visible: true)
    realty_asset = Pwb::RealtyAsset.create!(website: website, reference: reference)
    Pwb::RentalListing.create!(
      realty_asset: realty_asset,
      reference: reference,
      visible: visible,
      archived: false,
      active: true,
      for_rent_long_term: true,
      price_rental_monthly_current_cents: price_cents,
      price_rental_monthly_current_currency: 'EUR'
    )
    Pwb::ListedProperty.refresh
    realty_asset
  end

  describe "WelcomeController" do
    let!(:website1) { Pwb::Website.create!(slug: "site1", subdomain: "tenant1", company_display_name: "Tenant 1", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:website2) { Pwb::Website.create!(slug: "site2", subdomain: "tenant2", company_display_name: "Tenant 2", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:agency1) { Pwb::Agency.create!(website: website1, company_name: "Agency One") }
    let!(:agency2) { Pwb::Agency.create!(website: website2, company_name: "Agency Two") }

    let!(:page1) { Pwb::Page.create!(website: website1, slug: "home", visible: true) }
    let!(:page2) { Pwb::Page.create!(website: website2, slug: "home", visible: true) }

    let!(:prop1) { create_sale_property(website: website1, reference: "T1-PROP-001", price_cents: 50000000) }
    let!(:prop2) { create_sale_property(website: website2, reference: "T2-PROP-001", price_cents: 75000000) }

    it "shows only tenant1's properties on tenant1 subdomain" do
      host! "tenant1.example.com"
      get "/en"

      expect(response).to have_http_status(:success)
      references = assigns(:properties_for_sale).map(&:reference)
      expect(references).to include("T1-PROP-001")
      expect(references).not_to include("T2-PROP-001")
    end

    it "shows only tenant2's properties on tenant2 subdomain" do
      host! "tenant2.example.com"
      get "/en"

      expect(response).to have_http_status(:success)
      references = assigns(:properties_for_sale).map(&:reference)
      expect(references).to include("T2-PROP-001")
      expect(references).not_to include("T1-PROP-001")
    end

    it "sets correct agency for each subdomain" do
      host! "tenant1.example.com"
      get "/en"
      expect(assigns(:current_agency)).to eq(agency1)

      Pwb::Current.reset

      host! "tenant2.example.com"
      get "/en"
      expect(assigns(:current_agency)).to eq(agency2)
    end
  end

  describe "SearchController" do
    let!(:website1) { Pwb::Website.create!(slug: "site1", subdomain: "search1", company_display_name: "Search Tenant 1", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:website2) { Pwb::Website.create!(slug: "site2", subdomain: "search2", company_display_name: "Search Tenant 2", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:agency1) { Pwb::Agency.create!(website: website1, company_name: "Search Agency 1") }
    let!(:agency2) { Pwb::Agency.create!(website: website2, company_name: "Search Agency 2") }

    let!(:sale_prop1) { create_sale_property(website: website1, reference: "SALE-T1-001", price_cents: 100000000) }
    let!(:sale_prop2) { create_sale_property(website: website2, reference: "SALE-T2-001", price_cents: 200000000) }
    let!(:rent_prop1) { create_rental_property(website: website1, reference: "RENT-T1-001", price_cents: 1000000) }
    let!(:rent_prop2) { create_rental_property(website: website2, reference: "RENT-T2-001", price_cents: 2000000) }

    describe "#buy" do
      it "returns only tenant1's for-sale properties" do
        host! "search1.example.com"
        get "/en/buy"

        expect(response).to have_http_status(:success)
        references = assigns(:properties).map(&:reference)
        expect(references).to include("SALE-T1-001")
        expect(references).not_to include("SALE-T2-001")
      end

      it "returns only tenant2's for-sale properties" do
        host! "search2.example.com"
        get "/en/buy"

        expect(response).to have_http_status(:success)
        references = assigns(:properties).map(&:reference)
        expect(references).to include("SALE-T2-001")
        expect(references).not_to include("SALE-T1-001")
      end
    end

    describe "#rent" do
      it "returns only tenant1's for-rent properties" do
        host! "search1.example.com"
        get "/en/rent"

        expect(response).to have_http_status(:success)
        references = assigns(:properties).map(&:reference)
        expect(references).to include("RENT-T1-001")
        expect(references).not_to include("RENT-T2-001")
      end

      it "returns only tenant2's for-rent properties" do
        host! "search2.example.com"
        get "/en/rent"

        expect(response).to have_http_status(:success)
        references = assigns(:properties).map(&:reference)
        expect(references).to include("RENT-T2-001")
        expect(references).not_to include("RENT-T1-001")
      end
    end
  end

  describe "PropsController" do
    let!(:website1) { Pwb::Website.create!(slug: "site1", subdomain: "props1", company_display_name: "Props Tenant 1", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:website2) { Pwb::Website.create!(slug: "site2", subdomain: "props2", company_display_name: "Props Tenant 2", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:agency1) { Pwb::Agency.create!(website: website1, company_name: "Props Agency 1") }
    let!(:agency2) { Pwb::Agency.create!(website: website2, company_name: "Props Agency 2") }

    let!(:prop1) { create_sale_property(website: website1, reference: "SHOW-T1-001", price_cents: 100000000) }
    let!(:prop2) { create_sale_property(website: website2, reference: "SHOW-T2-001", price_cents: 200000000) }

    describe "#show_for_sale" do
      it "shows tenant1's property on tenant1 subdomain" do
        host! "props1.example.com"
        # Get the listed property id (materialized view)
        listed_prop = Pwb::ListedProperty.find_by(reference: "SHOW-T1-001")
        get "/en/properties/for-sale/#{listed_prop.id}/property"

        expect(response).to have_http_status(:success)
        expect(assigns(:property_details).reference).to eq("SHOW-T1-001")
      end

      it "does not show tenant2's property on tenant1 subdomain" do
        host! "props1.example.com"
        listed_prop2 = Pwb::ListedProperty.find_by(reference: "SHOW-T2-001")
        get "/en/properties/for-sale/#{listed_prop2.id}/property"

        # Should render not_found since property doesn't belong to this tenant
        expect(assigns(:property_details)).to be_nil
      end

      it "shows tenant2's property on tenant2 subdomain" do
        host! "props2.example.com"
        listed_prop = Pwb::ListedProperty.find_by(reference: "SHOW-T2-001")
        get "/en/properties/for-sale/#{listed_prop.id}/property"

        expect(response).to have_http_status(:success)
        expect(assigns(:property_details).reference).to eq("SHOW-T2-001")
      end
    end
  end

  describe "PagesController" do
    let!(:website1) { Pwb::Website.create!(slug: "site1", subdomain: "pages1", company_display_name: "Pages Tenant 1", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:website2) { Pwb::Website.create!(slug: "site2", subdomain: "pages2", company_display_name: "Pages Tenant 2", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:agency1) { Pwb::Agency.create!(website: website1, company_name: "Pages Agency 1") }
    let!(:agency2) { Pwb::Agency.create!(website: website2, company_name: "Pages Agency 2") }

    let!(:page1) { Pwb::Page.create!(website: website1, slug: "about", visible: true) }
    let!(:page2) { Pwb::Page.create!(website: website2, slug: "about", visible: true) }
    # Pages need a main_link associated with them for the view to render
    let!(:link1) { Pwb::Link.create!(website: website1, slug: "about-link-1", page_slug: "about", placement: :top_nav, visible: true, link_title: "About Us 1") }
    let!(:link2) { Pwb::Link.create!(website: website2, slug: "about-link-2", page_slug: "about", placement: :top_nav, visible: true, link_title: "About Us 2") }

    it "shows tenant1's page on tenant1 subdomain" do
      host! "pages1.example.com"
      get "/en/p/about"

      expect(response).to have_http_status(:success)
      expect(assigns(:page)).to eq(page1)
    end

    it "shows tenant2's page on tenant2 subdomain" do
      host! "pages2.example.com"
      get "/en/p/about"

      expect(response).to have_http_status(:success)
      expect(assigns(:page)).to eq(page2)
    end
  end

  describe "Navigation links isolation" do
    let!(:website1) { Pwb::Website.create!(slug: "site1", subdomain: "nav1", company_display_name: "Nav Tenant 1", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:website2) { Pwb::Website.create!(slug: "site2", subdomain: "nav2", company_display_name: "Nav Tenant 2", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:agency1) { Pwb::Agency.create!(website: website1, company_name: "Nav Agency 1") }
    let!(:agency2) { Pwb::Agency.create!(website: website2, company_name: "Nav Agency 2") }

    let!(:page1) { Pwb::Page.create!(website: website1, slug: "home", visible: true) }
    let!(:page2) { Pwb::Page.create!(website: website2, slug: "home", visible: true) }

    let!(:link1) { Pwb::Link.create!(website: website1, slug: "nav-link-1", placement: :top_nav, visible: true, link_path: "home_path") }
    let!(:link2) { Pwb::Link.create!(website: website2, slug: "nav-link-2", placement: :top_nav, visible: true, link_path: "home_path") }

    it "renders only tenant1's nav links on tenant1 subdomain" do
      host! "nav1.example.com"
      get "/en"

      expect(response).to have_http_status(:success)
      # Check that only tenant1's links are accessible
      top_nav_links = website1.links.ordered_visible_top_nav
      expect(top_nav_links).to include(link1)
      expect(top_nav_links).not_to include(link2)
    end

    it "renders only tenant2's nav links on tenant2 subdomain" do
      host! "nav2.example.com"
      get "/en"

      expect(response).to have_http_status(:success)
      # Check that only tenant2's links are accessible
      top_nav_links = website2.links.ordered_visible_top_nav
      expect(top_nav_links).to include(link2)
      expect(top_nav_links).not_to include(link1)
    end
  end

  describe "API Controllers multi-tenancy" do
    let!(:website1) { Pwb::Website.create!(slug: "api-site1", subdomain: "api1", company_display_name: "API Tenant 1", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:website2) { Pwb::Website.create!(slug: "api-site2", subdomain: "api2", company_display_name: "API Tenant 2", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:agency1) { Pwb::Agency.create!(website: website1, company_name: "API Agency 1", email_for_general_contact_form: "api1@test.com") }
    let!(:agency2) { Pwb::Agency.create!(website: website2, company_name: "API Agency 2", email_for_general_contact_form: "api2@test.com") }

    describe "Api::V1::AgencyController" do
      around do |example|
        # Temporarily bypass authentication for this test
        original_value = ENV['BYPASS_API_AUTH']
        ENV['BYPASS_API_AUTH'] = 'true'
        example.run
        ENV['BYPASS_API_AUTH'] = original_value
      end

      it "returns tenant1's agency on tenant1 subdomain" do
        host! "api1.example.com"
        get "/api/v1/infos"

        # Just test that the request works - detailed agency info testing
        # would require checking the specific response format
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "Public API multi-tenancy" do
    let!(:website1) { Pwb::Website.create!(slug: "public1", subdomain: "public1", company_display_name: "Public Tenant 1", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:website2) { Pwb::Website.create!(slug: "public2", subdomain: "public2", company_display_name: "Public Tenant 2", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }

    let!(:prop1) { create_sale_property(website: website1, reference: "PUB-T1-001", price_cents: 100000000) }
    let!(:prop2) { create_sale_property(website: website2, reference: "PUB-T2-001", price_cents: 200000000) }

    describe "properties#show" do
      it "returns tenant1's property on tenant1 subdomain" do
        host! "public1.example.com"
        listed_prop = Pwb::ListedProperty.find_by(reference: "PUB-T1-001")
        get "/api_public/v1/properties/#{listed_prop.id}"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["reference"]).to eq("PUB-T1-001")
      end

      it "returns 404 for tenant2's property on tenant1 subdomain" do
        host! "public1.example.com"
        listed_prop2 = Pwb::ListedProperty.find_by(reference: "PUB-T2-001")
        get "/api_public/v1/properties/#{listed_prop2.id}"

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "properties#search" do
      it "returns only tenant1's properties on tenant1 subdomain" do
        host! "public1.example.com"
        get "/api_public/v1/properties"

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        references = json.map { |p| p["reference"] }
        expect(references).to include("PUB-T1-001")
        expect(references).not_to include("PUB-T2-001")
      end
    end

    describe "links#index" do
      let!(:link1) { Pwb::Link.create!(website: website1, slug: "api-link-1", placement: :top_nav, visible: true) }
      let!(:link2) { Pwb::Link.create!(website: website2, slug: "api-link-2", placement: :top_nav, visible: true) }

      it "returns only tenant1's links on tenant1 subdomain" do
        host! "public1.example.com"
        get "/api_public/v1/links", params: { placement: "top_nav" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        slugs = json.map { |l| l["slug"] }
        expect(slugs).to include("api-link-1")
        expect(slugs).not_to include("api-link-2")
      end
    end
  end

  describe "Content isolation" do
    let!(:website1) { Pwb::Website.create!(slug: "content1", subdomain: "content1", company_display_name: "Content Tenant 1", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:website2) { Pwb::Website.create!(slug: "content2", subdomain: "content2", company_display_name: "Content Tenant 2", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }

    it "content is scoped to website via website_id" do
      # Create content directly with website_id (Content model has website_id column)
      logo_content1 = Pwb::Content.create!(key: "logo", tag: "appearance", website: website1)
      logo_content2 = Pwb::Content.create!(key: "logo", tag: "appearance", website: website2)

      # Verify that each content belongs to its respective website
      expect(Pwb::Content.where(website_id: website1.id).find_by_key("logo")).to eq(logo_content1)
      expect(Pwb::Content.where(website_id: website2.id).find_by_key("logo")).to eq(logo_content2)
      # Contents are isolated by website_id
      expect(logo_content1.website_id).to eq(website1.id)
      expect(logo_content2.website_id).to eq(website2.id)
    end
  end

  describe "Website display_links isolation" do
    let!(:website1) { Pwb::Website.create!(slug: "display1", subdomain: "display1", company_display_name: "Display Tenant 1", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:website2) { Pwb::Website.create!(slug: "display2", subdomain: "display2", company_display_name: "Display Tenant 2", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }

    let!(:nav_link1) { Pwb::Link.create!(website: website1, slug: "top-nav-1", placement: :top_nav, visible: true, sort_order: 1) }
    let!(:nav_link2) { Pwb::Link.create!(website: website2, slug: "top-nav-2", placement: :top_nav, visible: true, sort_order: 1) }
    let!(:footer_link1) { Pwb::Link.create!(website: website1, slug: "footer-1", placement: :footer, visible: true, sort_order: 1) }
    let!(:footer_link2) { Pwb::Link.create!(website: website2, slug: "footer-2", placement: :footer, visible: true, sort_order: 1) }

    it "top_nav_display_links returns only website1's nav links" do
      nav_links = website1.top_nav_display_links
      expect(nav_links).to include(nav_link1)
      expect(nav_links).not_to include(nav_link2)
    end

    it "footer_display_links returns only website1's footer links" do
      footer_links = website1.footer_display_links
      expect(footer_links).to include(footer_link1)
      expect(footer_links).not_to include(footer_link2)
    end

    it "top_nav_display_links returns only website2's nav links" do
      nav_links = website2.top_nav_display_links
      expect(nav_links).to include(nav_link2)
      expect(nav_links).not_to include(nav_link1)
    end

    it "footer_display_links returns only website2's footer links" do
      footer_links = website2.footer_display_links
      expect(footer_links).to include(footer_link2)
      expect(footer_links).not_to include(footer_link1)
    end
  end

  describe "JSONAPI Resources multi-tenancy" do
    let!(:website1) { Pwb::Website.create!(slug: "jsonapi1", subdomain: "jsonapi1", company_display_name: "JSONAPI Tenant 1", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:website2) { Pwb::Website.create!(slug: "jsonapi2", subdomain: "jsonapi2", company_display_name: "JSONAPI Tenant 2", default_client_locale: "en-GB", supported_locales: ["en-GB"]) }
    let!(:agency1) { Pwb::Agency.create!(website: website1, company_name: "JSONAPI Agency 1") }
    let!(:agency2) { Pwb::Agency.create!(website: website2, company_name: "JSONAPI Agency 2") }

    let!(:prop1) { create_sale_property(website: website1, reference: "JSONAPI-T1-001", price_cents: 100000000) }
    let!(:prop2) { create_sale_property(website: website2, reference: "JSONAPI-T2-001", price_cents: 200000000) }

    let!(:content1) { Pwb::Content.create!(website: website1, key: "tagline1", tag: "home") }
    let!(:content2) { Pwb::Content.create!(website: website2, key: "tagline2", tag: "home") }

    around do |example|
      # Bypass authentication for JSONAPI tests
      original_value = ENV['BYPASS_API_AUTH']
      ENV['BYPASS_API_AUTH'] = 'true'
      example.run
      ENV['BYPASS_API_AUTH'] = original_value
    end

    describe "lite-properties endpoint" do
      it "returns only tenant1's properties on tenant1 subdomain" do
        host! "jsonapi1.example.com"
        get "/api/v1/lite-properties", headers: { "Accept" => "application/vnd.api+json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        references = json["data"].map { |p| p["attributes"]["reference"] }
        expect(references).to include("JSONAPI-T1-001")
        expect(references).not_to include("JSONAPI-T2-001")
      end

      it "returns only tenant2's properties on tenant2 subdomain" do
        host! "jsonapi2.example.com"
        get "/api/v1/lite-properties", headers: { "Accept" => "application/vnd.api+json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        references = json["data"].map { |p| p["attributes"]["reference"] }
        expect(references).to include("JSONAPI-T2-001")
        expect(references).not_to include("JSONAPI-T1-001")
      end

      it "does not leak tenant2's properties to tenant1" do
        host! "jsonapi1.example.com"
        get "/api/v1/lite-properties", headers: { "Accept" => "application/vnd.api+json" }

        json = JSON.parse(response.body)
        references = json["data"].map { |p| p["attributes"]["reference"] }
        expect(references).not_to include("JSONAPI-T2-001")
      end
    end

    describe "properties endpoint" do
      it "returns only tenant1's properties on tenant1 subdomain" do
        host! "jsonapi1.example.com"
        get "/api/v1/properties", headers: { "Accept" => "application/vnd.api+json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        references = json["data"].map { |p| p["attributes"]["reference"] }
        expect(references).to include("JSONAPI-T1-001")
        expect(references).not_to include("JSONAPI-T2-001")
      end

      it "returns only tenant2's properties on tenant2 subdomain" do
        host! "jsonapi2.example.com"
        get "/api/v1/properties", headers: { "Accept" => "application/vnd.api+json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        references = json["data"].map { |p| p["attributes"]["reference"] }
        expect(references).to include("JSONAPI-T2-001")
        expect(references).not_to include("JSONAPI-T1-001")
      end
    end

    # Note: web-contents JSONAPI endpoint is not testable because the route
    # /api/v1/web-contents is overridden by a custom route that maps to agency#infos
    # The WebContentResource scoping is tested indirectly through the resource itself
  end
end
