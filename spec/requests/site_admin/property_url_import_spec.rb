# frozen_string_literal: true

require "rails_helper"

RSpec.describe "SiteAdmin::PropertyUrlImportController", type: :request do
  let!(:website) { create(:pwb_website, subdomain: "url-import-test") }
  let!(:agency) { create(:pwb_agency, website: website) }
  let!(:admin_user) { create(:pwb_user, :admin, website: website, email: "admin@url-import.test") }

  before do
    sign_in admin_user
    allow(Pwb::Current).to receive(:website).and_return(website)
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe "GET /site_admin/property_url_import (new)" do
    it "renders the URL input form" do
      get site_admin_property_url_import_path,
          headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Import Property from URL")
    end
  end

  describe "POST /site_admin/property_url_import (create)" do
    context "with blank URL" do
      it "redirects with an alert" do
        post site_admin_property_url_import_path,
             params: { url: "" },
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        expect(response).to redirect_to(site_admin_property_url_import_path)
        expect(flash[:alert]).to include("Please enter a property URL")
      end
    end

    context "with invalid URL" do
      it "redirects with an alert" do
        post site_admin_property_url_import_path,
             params: { url: "not-a-valid-url" },
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        expect(response).to redirect_to(site_admin_property_url_import_path)
        expect(flash[:alert]).to include("Please enter a valid URL")
      end
    end

    context "with valid URL" do
      let(:url) { "https://www.rightmove.co.uk/properties/123456789" }
      let(:html_content) { "<html><head><title>Test</title></head><body>Content</body></html>" }

      before do
        connector_double = instance_double(Pwb::ScraperConnectors::Http)
        allow(Pwb::ScraperConnectors::Http).to receive(:new).and_return(connector_double)
        allow(connector_double).to receive(:fetch).and_return(fetch_result)
        # Disable Playwright fallback in tests
        allow(Pwb::ScraperConnectors::Playwright).to receive(:available?).and_return(false)
      end

      context "when scraping succeeds" do
        let(:fetch_result) do
          { success: true, html: html_content, final_url: url }
        end

        it "creates a ScrapedProperty record" do
          expect {
            post site_admin_property_url_import_path,
                 params: { url: url },
                 headers: { "HTTP_HOST" => "url-import-test.test.localhost" }
          }.to change(Pwb::ScrapedProperty, :count).by(1)
        end

        it "redirects to preview page" do
          post site_admin_property_url_import_path,
               params: { url: url },
               headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

          scraped = Pwb::ScrapedProperty.last
          expect(response).to redirect_to(site_admin_property_url_import_preview_path(scraped))
        end

        it "shows success message" do
          post site_admin_property_url_import_path,
               params: { url: url },
               headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

          expect(flash[:notice]).to include("Property data extracted successfully")
        end
      end

      context "when scraping fails" do
        let(:fetch_result) do
          { success: false, error: "Request blocked by Cloudflare" }
        end

        it "renders the manual HTML form" do
          post site_admin_property_url_import_path,
               params: { url: url },
               headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

          expect(response).to have_http_status(:success)
          expect(response.body).to include("Manual HTML Entry")
        end

        it "displays the error message" do
          post site_admin_property_url_import_path,
               params: { url: url },
               headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

          expect(response.body).to include("Request blocked by Cloudflare")
        end
      end
    end
  end

  describe "POST /site_admin/property_url_import/manual_html" do
    let(:url) { "https://www.rightmove.co.uk/properties/123456789" }
    let(:html) do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Test Property</title>
          <meta property="og:title" content="Beautiful Property">
        </head>
        <body><div class="price">£250,000</div></body>
        </html>
      HTML
    end

    context "with blank HTML" do
      it "renders the form with error" do
        post site_admin_property_url_import_manual_html_path,
             params: { url: url, raw_html: "" },
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Please paste the HTML source")
      end
    end

    context "with valid HTML" do
      it "creates/updates a ScrapedProperty record" do
        expect {
          post site_admin_property_url_import_manual_html_path,
               params: { url: url, raw_html: html },
               headers: { "HTTP_HOST" => "url-import-test.test.localhost" }
        }.to change(Pwb::ScrapedProperty, :count).by(1)
      end

      it "redirects to preview page" do
        post site_admin_property_url_import_manual_html_path,
             params: { url: url, raw_html: html },
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        scraped = Pwb::ScrapedProperty.last
        expect(response).to redirect_to(site_admin_property_url_import_preview_path(scraped))
      end

      it "shows success message" do
        post site_admin_property_url_import_manual_html_path,
             params: { url: url, raw_html: html },
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        expect(flash[:notice]).to include("HTML parsed successfully")
      end
    end
  end

  describe "GET /site_admin/property_url_import/:id/preview" do
    let!(:scraped_property) do
      create(:pwb_scraped_property, :with_successful_scrape, website: website)
    end

    it "renders the preview page" do
      get site_admin_property_url_import_preview_path(scraped_property),
          headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Review Imported Data")
    end

    it "displays extracted data" do
      get site_admin_property_url_import_preview_path(scraped_property),
          headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

      expect(response.body).to include("Property Details")
      expect(response.body).to include("London") # City from factory
    end

    context "when property cannot be previewed" do
      let!(:failed_scrape) do
        create(:pwb_scraped_property, :with_failed_scrape, website: website)
      end

      it "redirects to new form with alert" do
        get site_admin_property_url_import_preview_path(failed_scrape),
            headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        expect(response).to redirect_to(site_admin_property_url_import_path)
        expect(flash[:alert]).to include("Unable to preview")
      end
    end

    context "multi-tenancy" do
      let!(:other_website) { create(:pwb_website, subdomain: "other-url-import") }
      let!(:other_scraped) do
        create(:pwb_scraped_property, :with_successful_scrape, website: other_website)
      end

      it "returns 404 for other website's scraped property" do
        get site_admin_property_url_import_preview_path(other_scraped),
            headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        # Controller raises RecordNotFound which Rails converts to 404
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /site_admin/property_url_import/:id/confirm" do
    let!(:scraped_property) do
      create(:pwb_scraped_property, :with_successful_scrape, website: website)
    end

    it "creates a RealtyAsset" do
      expect {
        post site_admin_property_url_import_confirm_path(scraped_property),
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }
      }.to change(Pwb::RealtyAsset, :count).by(1)
    end

    it "creates a SaleListing" do
      expect {
        post site_admin_property_url_import_confirm_path(scraped_property),
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }
      }.to change(Pwb::SaleListing, :count).by(1)
    end

    it "redirects to edit page" do
      post site_admin_property_url_import_confirm_path(scraped_property),
           headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

      expect(response).to redirect_to(edit_general_site_admin_prop_path(Pwb::RealtyAsset.last))
    end

    it "shows success message" do
      post site_admin_property_url_import_confirm_path(scraped_property),
           headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

      expect(flash[:notice]).to include("Property imported successfully")
    end

    context "with overrides from form" do
      it "applies asset_data overrides" do
        post site_admin_property_url_import_confirm_path(scraped_property),
             params: { asset_data: { count_bedrooms: 5, city: "Manchester" } },
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        asset = Pwb::RealtyAsset.last
        expect(asset.count_bedrooms).to eq(5)
        expect(asset.city).to eq("Manchester")
      end

      it "applies listing_data overrides" do
        post site_admin_property_url_import_confirm_path(scraped_property),
             params: { listing_data: { title: "Custom Title", price_sale_current: 500000 } },
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        listing = Pwb::SaleListing.last
        expect(listing.title).to eq("Custom Title")
      end
    end

    context "when already imported" do
      let!(:imported_property) do
        asset = create(:pwb_realty_asset, website: website)
        create(:pwb_scraped_property, :with_successful_scrape,
               website: website,
               import_status: "imported",
               realty_asset: asset)
      end

      it "redirects to existing property" do
        post site_admin_property_url_import_confirm_path(imported_property),
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        expect(response).to redirect_to(site_admin_prop_path(imported_property.realty_asset))
      end

      it "shows already imported message" do
        post site_admin_property_url_import_confirm_path(imported_property),
             headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        # Controller uses notice, not alert for already imported
        expect(flash[:notice]).to include("already been imported")
      end
    end
  end

  describe "GET /site_admin/property_url_import/history" do
    let!(:scraped1) do
      create(:pwb_scraped_property, :with_successful_scrape,
             website: website,
             source_url: "https://example.com/property/1")
    end
    let!(:scraped2) do
      create(:pwb_scraped_property, :with_failed_scrape,
             website: website,
             source_url: "https://example.com/property/2")
    end

    it "renders the history page" do
      get site_admin_property_url_import_history_path,
          headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Import History")
    end

    it "displays scraped properties" do
      get site_admin_property_url_import_history_path,
          headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

      expect(response.body).to include("example.com/property/1")
      expect(response.body).to include("example.com/property/2")
    end

    context "multi-tenancy" do
      let!(:other_website) { create(:pwb_website, subdomain: "other-history") }
      let!(:other_scraped) do
        create(:pwb_scraped_property, :with_successful_scrape,
               website: other_website,
               source_url: "https://other.com/property/999")
      end

      it "only shows current website's scraped properties" do
        get site_admin_property_url_import_history_path,
            headers: { "HTTP_HOST" => "url-import-test.test.localhost" }

        expect(response.body).not_to include("other.com/property/999")
      end
    end
  end
end
