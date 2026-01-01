# frozen_string_literal: true

require "rails_helper"

module Pwb
  RSpec.describe PropertyScraperService do
    let(:website) { create(:pwb_website) }
    let(:url) { "https://www.example-realty.com/properties/123456789" }

    describe "#initialize" do
      it "initializes with url and website" do
        service = described_class.new(url, website: website)
        expect(service.url).to eq(url)
        expect(service.website).to eq(website)
      end

      it "strips whitespace from url" do
        service = described_class.new("  #{url}  ", website: website)
        expect(service.url).to eq(url)
      end
    end

    describe "#call" do
      context "when URL was already successfully scraped" do
        let!(:existing) do
          create(:pwb_scraped_property, :with_successful_scrape,
                 website: website,
                 source_url: url)
        end

        it "returns the existing scraped property" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result).to eq(existing)
        end

        it "does not make HTTP requests" do
          expect(ScraperConnectors::Http).not_to receive(:new)
          service = described_class.new(url, website: website)
          service.call
        end
      end

      context "when scraping succeeds" do
        let(:html_content) do
          <<~HTML
            <!DOCTYPE html>
            <html>
            <head>
              <title>3 Bedroom Apartment for Sale</title>
              <meta property="og:title" content="Beautiful Apartment">
              <meta property="og:description" content="Stunning property in prime location">
            </head>
            <body>
              <h1 class="price">£450,000</h1>
              <div class="bedrooms">3 bedrooms</div>
            </body>
            </html>
          HTML
        end

        before do
          connector_double = instance_double(ScraperConnectors::Http)
          allow(ScraperConnectors::Http).to receive(:new).and_return(connector_double)
          allow(connector_double).to receive(:fetch).and_return({
            success: true,
            html: html_content,
            final_url: url
          })
        end

        it "creates a ScrapedProperty record" do
          service = described_class.new(url, website: website)
          expect { service.call }.to change(ScrapedProperty, :count).by(1)
        end

        it "marks the scrape as successful" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result.scrape_successful).to be true
        end

        it "stores the raw HTML" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result.raw_html).to eq(html_content)
        end

        it "sets scrape_method to auto" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result.scrape_method).to eq("auto")
        end

        it "sets connector_used to http" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result.connector_used).to eq("http")
        end

        it "sets import_status to previewing" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result.import_status).to eq("previewing")
        end

        it "extracts data using the appropriate pasarela" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result.extracted_data).to be_present
        end

        it "detects the source portal" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result.source_portal).to eq("generic")
        end
      end

      context "when scraping fails" do
        before do
          connector_double = instance_double(ScraperConnectors::Http)
          allow(ScraperConnectors::Http).to receive(:new).and_return(connector_double)
          allow(connector_double).to receive(:fetch).and_return({
            success: false,
            error: "Request blocked by Cloudflare",
            error_class: "Pwb::ScraperConnectors::BlockedError"
          })
          # Disable Playwright fallback in tests
          allow(ScraperConnectors::Playwright).to receive(:available?).and_return(false)
        end

        it "creates a ScrapedProperty record" do
          service = described_class.new(url, website: website)
          expect { service.call }.to change(ScrapedProperty, :count).by(1)
        end

        it "marks the scrape as unsuccessful" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result.scrape_successful).to be false
        end

        it "stores the error message" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result.scrape_error_message).to eq("Request blocked by Cloudflare")
        end

        it "keeps import_status as pending" do
          service = described_class.new(url, website: website)
          result = service.call
          expect(result.import_status).to eq("pending")
        end
      end

      context "with different portal URLs" do
        before do
          connector_double = instance_double(ScraperConnectors::Http)
          allow(ScraperConnectors::Http).to receive(:new).and_return(connector_double)
          allow(connector_double).to receive(:fetch).and_return({
            success: true,
            html: "<html><body>Test</body></html>",
            final_url: url
          })
        end

        it "detects zoopla portal" do
          service = described_class.new("https://www.zoopla.co.uk/for-sale/details/123", website: website)
          result = service.call
          expect(result.source_portal).to eq("zoopla")
        end

        it "detects idealista portal" do
          service = described_class.new("https://www.idealista.com/inmueble/123/", website: website)
          result = service.call
          expect(result.source_portal).to eq("idealista")
        end

        it "defaults to generic for unknown portals" do
          service = described_class.new("https://www.unknown-realty.com/property/123", website: website)
          result = service.call
          expect(result.source_portal).to eq("generic")
        end
      end
    end

    describe "#import_from_manual_html" do
      let(:manual_html) do
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>Manual Property</title>
            <meta property="og:title" content="Manually Imported Property">
          </head>
          <body>
            <div class="price">€250,000</div>
          </body>
          </html>
        HTML
      end

      it "creates a ScrapedProperty record" do
        service = described_class.new(url, website: website)
        expect { service.import_from_manual_html(manual_html) }.to change(ScrapedProperty, :count).by(1)
      end

      it "marks the scrape as successful" do
        service = described_class.new(url, website: website)
        result = service.import_from_manual_html(manual_html)
        expect(result.scrape_successful).to be true
      end

      it "stores the raw HTML" do
        service = described_class.new(url, website: website)
        result = service.import_from_manual_html(manual_html)
        expect(result.raw_html).to eq(manual_html)
      end

      it "sets scrape_method to manual_html" do
        service = described_class.new(url, website: website)
        result = service.import_from_manual_html(manual_html)
        expect(result.scrape_method).to eq("manual_html")
      end

      it "sets connector_used to nil" do
        service = described_class.new(url, website: website)
        result = service.import_from_manual_html(manual_html)
        expect(result.connector_used).to be_nil
      end

      it "sets import_status to previewing" do
        service = described_class.new(url, website: website)
        result = service.import_from_manual_html(manual_html)
        expect(result.import_status).to eq("previewing")
      end

      it "extracts data from the HTML" do
        service = described_class.new(url, website: website)
        result = service.import_from_manual_html(manual_html)
        expect(result.extracted_data).to be_present
      end

      context "when scraped property already exists for URL" do
        let!(:existing) do
          create(:pwb_scraped_property, :with_failed_scrape, website: website, source_url: url)
        end

        it "updates the existing record instead of creating new" do
          service = described_class.new(url, website: website)
          expect { service.import_from_manual_html(manual_html) }.not_to change(ScrapedProperty, :count)
        end

        it "updates the existing record with new data" do
          service = described_class.new(url, website: website)
          result = service.import_from_manual_html(manual_html)
          expect(result.id).to eq(existing.id)
          expect(result.scrape_successful).to be true
          expect(result.raw_html).to eq(manual_html)
        end
      end
    end
  end
end
