# frozen_string_literal: true

require "rails_helper"

module Pwb
  RSpec.describe ScrapedProperty, type: :model do
    let(:website) { create(:pwb_website) }
    let(:scraped_property) { create(:pwb_scraped_property, website: website) }

    describe "associations" do
      it "belongs to website" do
        expect(scraped_property.website).to eq(website)
      end

      it "optionally belongs to realty_asset" do
        sp = build(:pwb_scraped_property, website: website, realty_asset: nil)
        expect(sp).to be_valid
      end

      it "can have an associated realty_asset after import" do
        realty_asset = create(:pwb_realty_asset, website: website)
        scraped_property.update!(realty_asset: realty_asset)
        expect(scraped_property.reload.realty_asset).to eq(realty_asset)
      end
    end

    describe "validations" do
      it "requires source_url" do
        sp = build(:pwb_scraped_property, website: website, source_url: nil)
        expect(sp).not_to be_valid
        expect(sp.errors[:source_url]).to include("can't be blank")
      end

      it "requires website" do
        sp = build(:pwb_scraped_property, website: nil)
        expect(sp).not_to be_valid
        expect(sp.errors[:website]).to include("must exist")
      end
    end

    describe "callbacks" do
      describe "#normalize_source_url" do
        it "normalizes the source URL on save" do
          sp = create(:pwb_scraped_property,
                      website: website,
                      source_url: "https://www.rightmove.co.uk/properties/123456789/?channel=RES_BUY")
          # Trailing slashes are stripped during normalization
          expect(sp.source_url_normalized).to eq("www.rightmove.co.uk/properties/123456789")
        end

        it "extracts the host from the URL" do
          sp = create(:pwb_scraped_property,
                      website: website,
                      source_url: "https://www.zoopla.co.uk/for-sale/details/12345")
          expect(sp.source_host).to eq("www.zoopla.co.uk")
        end

        it "handles URLs with trailing slashes" do
          sp = create(:pwb_scraped_property,
                      website: website,
                      source_url: "https://example.com/property/123/")
          expect(sp.source_url_normalized).to eq("example.com/property/123")
        end
      end

      describe "#detect_source_portal" do
        it "detects rightmove portal" do
          sp = create(:pwb_scraped_property,
                      website: website,
                      source_url: "https://www.rightmove.co.uk/properties/123")
          expect(sp.source_portal).to eq("rightmove")
        end

        it "detects zoopla portal" do
          sp = create(:pwb_scraped_property,
                      website: website,
                      source_url: "https://www.zoopla.co.uk/for-sale/details/123")
          expect(sp.source_portal).to eq("zoopla")
        end

        it "detects idealista portal" do
          sp = create(:pwb_scraped_property,
                      website: website,
                      source_url: "https://www.idealista.com/inmueble/123/")
          expect(sp.source_portal).to eq("idealista")
        end

        it "detects zillow portal" do
          sp = create(:pwb_scraped_property,
                      website: website,
                      source_url: "https://www.zillow.com/homedetails/123")
          expect(sp.source_portal).to eq("zillow")
        end

        it "defaults to generic for unknown portals" do
          sp = create(:pwb_scraped_property,
                      website: website,
                      source_url: "https://www.unknownportal.com/property/123")
          expect(sp.source_portal).to eq("generic")
        end
      end
    end

    describe "scopes" do
      before do
        create(:pwb_scraped_property, website: website, import_status: "pending")
        create(:pwb_scraped_property, website: website, import_status: "previewing")
        create(:pwb_scraped_property, website: website, import_status: "imported")
        create(:pwb_scraped_property, website: website, scrape_successful: true, import_status: "previewing")
        create(:pwb_scraped_property, website: website, scrape_successful: false)
      end

      it ".pending returns pending imports" do
        expect(ScrapedProperty.pending.count).to eq(2) # pending + failed both have pending
      end

      it ".previewing returns imports ready for review" do
        expect(ScrapedProperty.previewing.count).to eq(2)
      end

      it ".imported returns completed imports" do
        expect(ScrapedProperty.imported.count).to eq(1)
      end

      it ".successful returns successfully scraped items" do
        expect(ScrapedProperty.successful.count).to eq(1)
      end

      it ".failed returns failed scrapes" do
        expect(ScrapedProperty.failed.count).to eq(4)
      end
    end

    describe "instance methods" do
      describe "#asset_data" do
        it "returns asset_data from extracted_data" do
          sp = create(:pwb_scraped_property, :with_successful_scrape, website: website)
          expect(sp.asset_data).to include("count_bedrooms" => 3)
        end

        it "returns empty hash when no extracted_data" do
          expect(scraped_property.asset_data).to eq({})
        end
      end

      describe "#listing_data" do
        it "returns listing_data from extracted_data" do
          sp = create(:pwb_scraped_property, :with_successful_scrape, website: website)
          expect(sp.listing_data).to include("price_sale_current" => 450000)
        end

        it "returns empty hash when no extracted_data" do
          expect(scraped_property.listing_data).to eq({})
        end
      end

      describe "#images" do
        it "returns extracted_images" do
          sp = create(:pwb_scraped_property, :with_successful_scrape, website: website)
          expect(sp.images).to eq(["https://example.com/image1.jpg", "https://example.com/image2.jpg"])
        end

        it "returns empty array when no images" do
          expect(scraped_property.images).to eq([])
        end
      end

      describe "#can_preview?" do
        it "returns true when scrape successful and has extracted data" do
          sp = create(:pwb_scraped_property, :with_successful_scrape, website: website)
          expect(sp.can_preview?).to be true
        end

        it "returns false when scrape failed" do
          sp = create(:pwb_scraped_property, :with_failed_scrape, website: website)
          expect(sp.can_preview?).to be false
        end

        it "returns false when no extracted data" do
          sp = create(:pwb_scraped_property, website: website, scrape_successful: true, extracted_data: {})
          expect(sp.can_preview?).to be false
        end
      end

      describe "#already_imported?" do
        it "returns true when imported and has realty_asset" do
          realty_asset = create(:pwb_realty_asset, website: website)
          sp = create(:pwb_scraped_property, :with_successful_scrape,
                      website: website,
                      import_status: "imported",
                      realty_asset: realty_asset)
          expect(sp.already_imported?).to be true
        end

        it "returns false when not imported" do
          sp = create(:pwb_scraped_property, :with_successful_scrape, website: website)
          expect(sp.already_imported?).to be false
        end
      end

      describe "#mark_as_previewing!" do
        it "updates import_status to previewing" do
          scraped_property.mark_as_previewing!
          expect(scraped_property.reload.import_status).to eq("previewing")
        end
      end

      describe "#mark_as_imported!" do
        it "updates import_status and sets realty_asset" do
          realty_asset = create(:pwb_realty_asset, website: website)
          scraped_property.mark_as_imported!(realty_asset)
          scraped_property.reload
          expect(scraped_property.import_status).to eq("imported")
          expect(scraped_property.realty_asset).to eq(realty_asset)
          expect(scraped_property.imported_at).to be_present
        end
      end

      describe "#mark_as_failed!" do
        it "updates import_status and sets error message" do
          scraped_property.mark_as_failed!("Something went wrong")
          scraped_property.reload
          expect(scraped_property.import_status).to eq("failed")
          expect(scraped_property.scrape_error_message).to eq("Something went wrong")
        end
      end
    end

    describe "factory traits" do
      it "creates with successful scrape trait" do
        sp = create(:pwb_scraped_property, :with_successful_scrape, website: website)
        expect(sp.scrape_successful).to be true
        expect(sp.can_preview?).to be true
      end

      it "creates with failed scrape trait" do
        sp = create(:pwb_scraped_property, :with_failed_scrape, website: website)
        expect(sp.scrape_successful).to be false
        expect(sp.scrape_error_message).to be_present
      end

      it "creates with manual HTML trait" do
        sp = create(:pwb_scraped_property, :with_manual_html, website: website)
        expect(sp.scrape_method).to eq("manual_html")
        expect(sp.connector_used).to be_nil
      end

      it "creates with portal traits" do
        rightmove = create(:pwb_scraped_property, :from_rightmove, website: website)
        expect(rightmove.source_portal).to eq("rightmove")

        zoopla = create(:pwb_scraped_property, :from_zoopla, website: website)
        expect(zoopla.source_portal).to eq("zoopla")
      end
    end
  end
end
