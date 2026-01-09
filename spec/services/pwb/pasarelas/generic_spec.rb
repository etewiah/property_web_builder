# frozen_string_literal: true

require "rails_helper"

module Pwb
  module Pasarelas
    RSpec.describe Generic do
      let(:website) { create(:pwb_website) }
      let(:scraped_property) do
        create(:pwb_scraped_property,
               website: website,
               source_url: "https://www.example.com/property/123",
               raw_html: html_content)
      end
      let(:pasarela) { described_class.new(scraped_property) }

      describe "#call" do
        context "with JSON-LD RealEstateListing" do
          let(:html_content) do
            <<~HTML
              <!DOCTYPE html>
              <html>
              <head>
                <title>3 Bedroom Apartment - London</title>
                <script type="application/ld+json">
                {
                  "@type": "RealEstateListing",
                  "name": "Beautiful 3 Bedroom Apartment",
                  "description": "A stunning property in the heart of London",
                  "numberOfBedrooms": 3,
                  "numberOfBathroomsTotal": 2,
                  "floorSize": {"value": 120, "unitCode": "SQM"},
                  "address": {
                    "streetAddress": "123 Main Street",
                    "addressLocality": "London",
                    "addressRegion": "Greater London",
                    "postalCode": "SW1A 1AA",
                    "addressCountry": "UK"
                  },
                  "geo": {
                    "latitude": 51.5074,
                    "longitude": -0.1278
                  },
                  "offers": {
                    "price": 450000,
                    "priceCurrency": "GBP"
                  }
                }
                </script>
              </head>
              <body>
                <img class="gallery" src="https://example.com/image1.jpg">
                <img class="gallery" src="https://example.com/image2.jpg">
              </body>
              </html>
            HTML
          end

          it "extracts property data from JSON-LD" do
            pasarela.call
            scraped_property.reload

            asset_data = scraped_property.asset_data
            expect(asset_data["count_bedrooms"]).to eq(3)
            expect(asset_data["count_bathrooms"]).to eq(2)
            expect(asset_data["constructed_area"]).to eq(120)
            expect(asset_data["city"]).to eq("London")
            expect(asset_data["postal_code"]).to eq("SW1A 1AA")
            expect(asset_data["latitude"]).to eq(51.5074)
            expect(asset_data["longitude"]).to eq(-0.1278)
          end

          it "extracts listing data from JSON-LD" do
            pasarela.call
            scraped_property.reload

            listing_data = scraped_property.listing_data
            expect(listing_data["title"]).to eq("Beautiful 3 Bedroom Apartment")
            expect(listing_data["description"]).to eq("A stunning property in the heart of London")
            expect(listing_data["price_sale_current"]).to eq(450_000)
            expect(listing_data["currency"]).to eq("GBP")
          end

          it "extracts images" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.images).to include("https://example.com/image1.jpg")
            expect(scraped_property.images).to include("https://example.com/image2.jpg")
          end
        end

        context "with Open Graph meta tags" do
          let(:html_content) do
            <<~HTML
              <!DOCTYPE html>
              <html>
              <head>
                <title>Property for Sale</title>
                <meta property="og:title" content="Lovely Family Home">
                <meta property="og:description" content="Perfect for growing families">
                <meta property="og:image" content="https://example.com/og-image.jpg">
              </head>
              <body>
                <div class="price">€350,000</div>
                <div class="bedrooms">4 bedrooms</div>
              </body>
              </html>
            HTML
          end

          it "extracts title from OG tags" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.listing_data["title"]).to eq("Lovely Family Home")
          end

          it "extracts description from OG tags" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.listing_data["description"]).to eq("Perfect for growing families")
          end

          it "extracts OG image" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.images).to include("https://example.com/og-image.jpg")
          end
        end

        context "with Next.js data" do
          let(:html_content) do
            <<~HTML
              <!DOCTYPE html>
              <html>
              <head>
                <title>Property Page</title>
                <script id="__NEXT_DATA__" type="application/json">
                {
                  "props": {
                    "pageProps": {
                      "property": {
                        "title": "Next.js Property",
                        "bedrooms": 2,
                        "bathrooms": 1,
                        "price": 200000,
                        "currency": "EUR",
                        "address": {
                          "city": "Barcelona",
                          "postcode": "08001"
                        }
                      }
                    }
                  }
                }
                </script>
              </head>
              <body></body>
              </html>
            HTML
          end

          it "extracts data from Next.js pageProps" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.asset_data["count_bedrooms"]).to eq(2)
            expect(scraped_property.asset_data["count_bathrooms"]).to eq(1)
          end
        end

        context "with HTML price selectors" do
          let(:html_content) do
            <<~HTML
              <!DOCTYPE html>
              <html>
              <head><title>Property</title></head>
              <body>
                <div class="listing-price">£275,000</div>
                <span class="bedrooms">3 beds</span>
                <span class="bathrooms">2 baths</span>
              </body>
              </html>
            HTML
          end

          it "extracts price from HTML" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.listing_data["price_sale_current"]).to eq(275_000)
            expect(scraped_property.listing_data["currency"]).to eq("GBP")
          end

          it "extracts bedrooms from HTML text" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.asset_data["count_bedrooms"]).to eq(3)
          end

          it "extracts bathrooms from HTML text" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.asset_data["count_bathrooms"]).to eq(2)
          end
        end

        context "with property type detection" do
          let(:html_content) do
            <<~HTML
              <!DOCTYPE html>
              <html>
              <head>
                <script type="application/ld+json">
                {"@type": "Apartment", "name": "Studio Apartment"}
                </script>
              </head>
              <body></body>
              </html>
            HTML
          end

          it "detects apartment type" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.asset_data["prop_type_key"]).to eq("apartment")
          end
        end

        context "with image gallery" do
          let(:html_content) do
            <<~HTML
              <!DOCTYPE html>
              <html>
              <head><title>Property</title></head>
              <body>
                <div class="gallery">
                  <img src="https://example.com/property/photo1.jpg">
                  <img src="https://example.com/property/photo2.jpg">
                  <img src="https://example.com/property/photo3.jpg">
                </div>
                <img src="https://example.com/logo.png">
                <img src="https://example.com/icons/share-button.png">
              </body>
              </html>
            HTML
          end

          it "extracts gallery images" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.images).to include("https://example.com/property/photo1.jpg")
            expect(scraped_property.images).to include("https://example.com/property/photo2.jpg")
          end

          it "skips logo and icon images" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.images).not_to include("https://example.com/logo.png")
            expect(scraped_property.images).not_to include("https://example.com/icons/share-button.png")
          end

          it "limits images to 20" do
            # Create HTML with 25 images
            many_images = (1..25).map { |i| %(<img src="https://example.com/photo#{i}.jpg">) }.join
            html = "<html><body><div class='gallery'>#{many_images}</div></body></html>"
            sp = create(:pwb_scraped_property, website: website, raw_html: html)
            p = described_class.new(sp)

            p.call
            sp.reload

            expect(sp.images.size).to be <= 20
          end
        end

        context "with address parsing" do
          let(:html_content) do
            <<~HTML
              <!DOCTYPE html>
              <html>
              <head><title>Property</title></head>
              <body>
                <div class="property-address">123 High Street, Manchester, M1 1AA</div>
              </body>
              </html>
            HTML
          end

          it "extracts address components" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.asset_data["street_address"]).to eq("123 High Street")
          end

          it "extracts postcode from address text" do
            pasarela.call
            scraped_property.reload

            expect(scraped_property.asset_data["postal_code"]).to eq("M1 1AA")
          end
        end

        context "with currency detection" do
          it "detects GBP from pound symbol" do
            html = '<html><body><div class="price">£100,000</div></body></html>'
            sp = create(:pwb_scraped_property, website: website, raw_html: html)
            p = described_class.new(sp)

            p.call
            sp.reload

            expect(sp.listing_data["currency"]).to eq("GBP")
          end

          it "detects USD from dollar symbol" do
            html = '<html><body><div class="price">$100,000</div></body></html>'
            sp = create(:pwb_scraped_property, website: website, raw_html: html)
            p = described_class.new(sp)

            p.call
            sp.reload

            expect(sp.listing_data["currency"]).to eq("USD")
          end

          it "detects EUR from euro symbol" do
            html = '<html><body><div class="price">€100,000</div></body></html>'
            sp = create(:pwb_scraped_property, website: website, raw_html: html)
            p = described_class.new(sp)

            p.call
            sp.reload

            expect(sp.listing_data["currency"]).to eq("EUR")
          end
        end

        context "with empty HTML" do
          let(:html_content) { "<html><body></body></html>" }

          it "returns empty data without errors" do
            result = pasarela.call
            expect(result[:asset_data]).to eq({})
            # Pasarela sets defaults for currency and visible
            expect(result[:listing_data]).to include("currency" => "EUR", "visible" => true)
            expect(result[:images]).to eq([])
          end
        end

        context "with malformed HTML" do
          let(:html_content) { "<html><div unclosed" }

          it "handles malformed HTML gracefully" do
            expect { pasarela.call }.not_to raise_error
          end
        end
      end
    end
  end
end
