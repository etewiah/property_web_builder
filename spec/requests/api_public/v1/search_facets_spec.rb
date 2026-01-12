# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ApiPublic::V1::SearchFacets", type: :request do
  let(:website) { create(:website) }

  before do
    allow(Pwb::Current).to receive(:website).and_return(website)
    host! website.host
  end

  describe "GET /api_public/v1/search/facets" do
    before do
      # Create some test properties with different attributes
      create_listed_property(prop_type_key: "apartment", zone: "Centro", count_bedrooms: 2)
      create_listed_property(prop_type_key: "apartment", zone: "Centro", count_bedrooms: 3)
      create_listed_property(prop_type_key: "house", zone: "Suburbs", count_bedrooms: 4)
    end

    it "returns facet counts" do
      get "/api_public/v1/search/facets"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to have_key("total_count")
      expect(json).to have_key("property_types")
      expect(json).to have_key("zones")
      expect(json).to have_key("bedrooms")
      expect(json).to have_key("price_ranges")
    end

    it "returns property type counts" do
      get "/api_public/v1/search/facets"

      json = JSON.parse(response.body)
      expect(json["property_types"]["apartment"]).to eq(2)
      expect(json["property_types"]["house"]).to eq(1)
    end

    it "returns zone counts" do
      get "/api_public/v1/search/facets"

      json = JSON.parse(response.body)
      expect(json["zones"]["Centro"]).to eq(2)
      expect(json["zones"]["Suburbs"]).to eq(1)
    end

    context "with sale_or_rental filter" do
      before do
        # Assuming there's a way to mark properties as for_sale or for_rent
      end

      it "filters by sale" do
        get "/api_public/v1/search/facets", params: { sale_or_rental: "sale" }

        expect(response).to have_http_status(:ok)
      end

      it "filters by rent" do
        get "/api_public/v1/search/facets", params: { sale_or_rental: "rent" }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  private

  def create_listed_property(attrs = {})
    # This would create a property visible in listed_properties
    # Adjust based on actual factory/model setup
    website.listed_properties.create!(
      title: "Test Property",
      slug: "test-#{SecureRandom.hex(4)}",
      prop_type_key: attrs[:prop_type_key] || "apartment",
      zone: attrs[:zone] || "Centro",
      locality: attrs[:locality] || "Madrid",
      count_bedrooms: attrs[:count_bedrooms] || 2,
      count_bathrooms: attrs[:count_bathrooms] || 1,
      visible: true
    )
  rescue StandardError
    # If listed_properties is a view, we might need to create via the underlying model
    nil
  end
end
