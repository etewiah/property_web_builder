# frozen_string_literal: true

require "rails_helper"

module Pwb
  module Pasarelas
    RSpec.describe Base do
      let(:website) { create(:pwb_website) }
      let(:scraped_property) do
        create(:pwb_scraped_property,
               website: website,
               source_url: "https://www.example.com/property/123",
               raw_html: html_content)
      end
      let(:pasarela) { described_class.new(scraped_property) }

      let(:html_content) do
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>Test Property - Beautiful Apartment</title>
            <meta name="description" content="A lovely apartment for sale">
            <meta property="og:title" content="OG Title">
            <meta property="og:description" content="OG Description">
            <meta property="og:image" content="https://example.com/image.jpg">
            <script type="application/ld+json">
            {
              "@type": "RealEstateListing",
              "name": "JSON-LD Title",
              "description": "JSON-LD Description",
              "numberOfBedrooms": 3
            }
            </script>
          </head>
          <body>
            <div class="address">123 Main Street, London</div>
            <div class="price">£450,000</div>
          </body>
          </html>
        HTML
      end

      describe "#initialize" do
        it "stores the scraped_property" do
          expect(pasarela.scraped_property).to eq(scraped_property)
        end

        it "stores the html" do
          expect(pasarela.html).to eq(html_content)
        end

        it "stores the url" do
          expect(pasarela.url).to eq("https://www.example.com/property/123")
        end

        it "parses the HTML into a Nokogiri document" do
          expect(pasarela.doc).to be_a(Nokogiri::HTML::Document)
        end
      end

      describe "#call" do
        it "raises NotImplementedError for base class" do
          expect { pasarela.call }.to raise_error(NotImplementedError)
        end
      end

      describe "extraction helpers" do
        # Create a test subclass to access protected methods
        let(:test_pasarela_class) do
          Class.new(Base) do
            def extract_data
              { asset_data: {}, listing_data: {}, images: [] }
            end

            # Expose protected methods for testing
            public :extract_json_ld, :extract_next_data, :extract_og_tags,
                   :meta_content, :clean_price, :extract_all_images,
                   :page_title, :meta_description, :text_at
          end
        end
        let(:test_pasarela) { test_pasarela_class.new(scraped_property) }

        describe "#extract_json_ld" do
          it "extracts JSON-LD data from script tags" do
            result = test_pasarela.extract_json_ld
            expect(result).to be_an(Array)
            expect(result.first["@type"]).to eq("RealEstateListing")
            expect(result.first["name"]).to eq("JSON-LD Title")
          end

          context "with invalid JSON" do
            let(:html_content) do
              <<~HTML
                <html>
                <head>
                  <script type="application/ld+json">{ invalid json }</script>
                </head>
                <body></body>
                </html>
              HTML
            end

            it "returns empty array for invalid JSON" do
              result = test_pasarela.extract_json_ld
              expect(result).to eq([])
            end
          end
        end

        describe "#extract_next_data" do
          context "with Next.js data" do
            let(:html_content) do
              <<~HTML
                <html>
                <head>
                  <script id="__NEXT_DATA__" type="application/json">
                  {"props":{"pageProps":{"property":{"title":"Next Property"}}}}
                  </script>
                </head>
                <body></body>
                </html>
              HTML
            end

            it "extracts Next.js page data" do
              result = test_pasarela.extract_next_data
              expect(result["props"]["pageProps"]["property"]["title"]).to eq("Next Property")
            end
          end

          context "without Next.js data" do
            it "returns nil" do
              result = test_pasarela.extract_next_data
              expect(result).to be_nil
            end
          end
        end

        describe "#extract_og_tags" do
          it "extracts Open Graph meta tags" do
            result = test_pasarela.extract_og_tags
            expect(result[:title]).to eq("OG Title")
            expect(result[:description]).to eq("OG Description")
            expect(result[:image]).to eq("https://example.com/image.jpg")
          end
        end

        describe "#meta_content" do
          it "extracts meta tag by property attribute" do
            result = test_pasarela.meta_content("og:title")
            expect(result).to eq("OG Title")
          end

          it "extracts meta tag by name attribute" do
            result = test_pasarela.meta_content("description")
            expect(result).to eq("A lovely apartment for sale")
          end

          it "returns nil for missing meta tag" do
            result = test_pasarela.meta_content("nonexistent")
            expect(result).to be_nil
          end
        end

        describe "#clean_price" do
          it "cleans price with currency symbol" do
            expect(test_pasarela.clean_price("£450,000")).to eq(450000.0)
          end

          it "cleans price with euro symbol" do
            expect(test_pasarela.clean_price("€250.000")).to eq(250000.0)
          end

          it "cleans price with dollar symbol" do
            expect(test_pasarela.clean_price("$1,234,567")).to eq(1234567.0)
          end

          it "handles European format" do
            expect(test_pasarela.clean_price("1.234.567,89")).to eq(1234567.89)
          end

          it "returns nil for blank input" do
            expect(test_pasarela.clean_price("")).to be_nil
            expect(test_pasarela.clean_price(nil)).to be_nil
          end
        end

        describe "#page_title" do
          it "extracts the page title" do
            expect(test_pasarela.page_title).to eq("Test Property - Beautiful Apartment")
          end
        end

        describe "#meta_description" do
          it "extracts the meta description" do
            expect(test_pasarela.meta_description).to eq("A lovely apartment for sale")
          end
        end

        describe "#text_at" do
          it "extracts text at CSS selector" do
            expect(test_pasarela.text_at(".address")).to eq("123 Main Street, London")
          end

          it "returns nil for missing selector" do
            expect(test_pasarela.text_at(".nonexistent")).to be_nil
          end
        end

        describe "#extract_all_images" do
          let(:html_content) do
            <<~HTML
              <html>
              <body>
                <img src="https://example.com/photo1.jpg" alt="Photo 1">
                <img data-src="https://example.com/photo2.jpg" alt="Photo 2">
                <img src="data:image/gif;base64,..." alt="Placeholder">
                <img src="/relative/photo3.jpg" alt="Photo 3">
              </body>
              </html>
            HTML
          end

          it "extracts image URLs from src attributes" do
            result = test_pasarela.extract_all_images
            expect(result).to include("https://example.com/photo1.jpg")
          end

          it "extracts image URLs from data-src attributes" do
            result = test_pasarela.extract_all_images
            expect(result).to include("https://example.com/photo2.jpg")
          end

          it "skips data URLs" do
            result = test_pasarela.extract_all_images
            expect(result.none? { |url| url.start_with?("data:") }).to be true
          end

          it "absolutizes relative URLs" do
            result = test_pasarela.extract_all_images
            expect(result).to include("https://www.example.com/relative/photo3.jpg")
          end
        end
      end

      context "with nil HTML" do
        let(:scraped_property) do
          create(:pwb_scraped_property, website: website, raw_html: nil)
        end

        it "handles nil HTML gracefully" do
          expect(pasarela.doc).to be_nil
        end
      end
    end
  end
end
