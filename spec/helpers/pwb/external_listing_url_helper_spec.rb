# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::ExternalListingUrlHelper, type: :helper do
  # Include route helpers - Rails app uses main_app routes
  before do
    helper.extend(Rails.application.routes.url_helpers)
  end

  describe "#external_listing_show_path" do
    context "with a sale listing" do
      let(:listing) do
        double(
          reference: "REF123",
          title: "Beautiful Villa in Marbella",
          listing_type: :sale
        )
      end

      it "generates the for-sale path" do
        result = helper.external_listing_show_path(listing)
        expect(result).to include("/external/for-sale/REF123/beautiful-villa-in-marbella")
      end
    end

    context "with a rental listing" do
      let(:listing) do
        double(
          reference: "RENT456",
          title: "Modern Apartment for Rent",
          listing_type: :rental
        )
      end

      it "generates the for-rent path" do
        result = helper.external_listing_show_path(listing)
        expect(result).to include("/external/for-rent/RENT456/modern-apartment-for-rent")
      end
    end

    context "with a short title" do
      let(:listing) do
        double(
          reference: "REF789",
          title: "AB",
          listing_type: :sale
        )
      end

      it "uses 'property' as the URL-friendly title" do
        result = helper.external_listing_show_path(listing)
        expect(result).to include("/external/for-sale/REF789/property")
      end
    end

    context "with nil listing" do
      it "returns '#'" do
        expect(helper.external_listing_show_path(nil)).to eq("#")
      end
    end

    context "with listing missing reference" do
      let(:listing) { double(reference: nil, title: "Test") }

      it "returns '#'" do
        expect(helper.external_listing_show_path(listing)).to eq("#")
      end
    end
  end

  describe "#external_listings_index_path" do
    it "returns external_buy_path for :sale" do
      result = helper.external_listings_index_path(:sale)
      expect(result).to include("/external/buy")
    end

    it "returns external_rent_path for :rental" do
      result = helper.external_listings_index_path(:rental)
      expect(result).to include("/external/rent")
    end

    it "defaults to sale when no argument" do
      result = helper.external_listings_index_path
      expect(result).to include("/external/buy")
    end

    it "handles string listing type" do
      result = helper.external_listings_index_path("rental")
      expect(result).to include("/external/rent")
    end
  end

  describe "#external_listings_search_path" do
    it "generates path with query parameters" do
      result = helper.external_listings_search_path(:sale, location: "marbella", min_price: 100_000)
      expect(result).to include("/external/buy")
      expect(result).to include("location=marbella")
      expect(result).to include("min_price=100000")
    end

    it "excludes blank parameters" do
      result = helper.external_listings_search_path(:sale, location: "marbella", min_price: "")
      expect(result).to include("location=marbella")
      expect(result).not_to include("min_price")
    end

    it "returns base path when no params" do
      result = helper.external_listings_search_path(:rental, {})
      expect(result).to eq(helper.external_rent_path)
    end
  end

  describe "#external_listings_page_path" do
    it "generates path with page parameter" do
      result = helper.external_listings_page_path(:sale, 2, {})
      expect(result).to include("/external/buy")
      expect(result).to include("page=2")
    end

    it "removes page parameter when page is 1" do
      result = helper.external_listings_page_path(:sale, 1, {})
      expect(result).not_to include("page=")
    end

    it "preserves existing parameters" do
      result = helper.external_listings_page_path(:rental, 3, location: "marbella")
      expect(result).to include("/external/rent")
      expect(result).to include("page=3")
      expect(result).to include("location=marbella")
    end
  end

  describe "#external_url_friendly_title" do
    it "parameterizes the title" do
      listing = double(title: "Beautiful Villa in Marbella")
      expect(helper.external_url_friendly_title(listing)).to eq("beautiful-villa-in-marbella")
    end

    it "returns 'property' for nil listing" do
      expect(helper.external_url_friendly_title(nil)).to eq("property")
    end

    it "returns 'property' for nil title" do
      listing = double(title: nil)
      expect(helper.external_url_friendly_title(listing)).to eq("property")
    end

    it "returns 'property' for short title (2 chars or less)" do
      listing = double(title: "AB")
      expect(helper.external_url_friendly_title(listing)).to eq("property")
    end

    it "handles special characters" do
      listing = double(title: "Villa á la Mode!")
      expect(helper.external_url_friendly_title(listing)).to eq("villa-a-la-mode")
    end
  end
end
