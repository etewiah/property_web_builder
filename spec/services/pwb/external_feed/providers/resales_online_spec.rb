# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

RSpec.describe Pwb::ExternalFeed::Providers::ResalesOnline do
  let(:website) { create(:website) }
  let(:config) do
    {
      api_key: "test_api_key_123",
      api_id_sales: "4069",
      api_id_rentals: "4070",
      p1_constant: "1014359"
    }
  end
  let(:provider) { described_class.new(website, config) }

  describe ".provider_name" do
    it "returns :resales_online" do
      expect(described_class.provider_name).to eq(:resales_online)
    end
  end

  describe ".display_name" do
    it "returns human readable name" do
      expect(described_class.display_name).to eq("Resales Online")
    end
  end

  describe "#initialize" do
    it "stores config values" do
      expect(provider.send(:config)[:api_key]).to eq("test_api_key_123")
      expect(provider.send(:config)[:api_id_sales]).to eq("4069")
    end

    it "raises error if required config missing" do
      expect do
        described_class.new(website, { api_key: "test" })
      end.to raise_error(Pwb::ExternalFeed::ConfigurationError)
    end
  end

  describe "#search" do
    let(:api_response) do
      {
        "transaction" => { "status" => "success" },
        "QueryInfo" => {
          "PropertyCount" => 2,
          "CurrentPage" => 1,
          "PropertiesPerPage" => 20
        },
        "Property" => [
          {
            "Reference" => "R123",
            "Type" => "Apartment",
            "PropertyType" => { "Type" => "Apartment", "OptionValue" => "1" },
            "Location" => "Marbella",
            "Province" => "Malaga",
            "Country" => "Spain",
            "Price" => 350_000,
            "Currency" => "EUR",
            "Bedrooms" => 2,
            "Bathrooms" => 1,
            "Built" => 85,
            "Description" => "Lovely apartment",
            "Pictures" => {
              "Count" => 1,
              "Picture" => [{ "PictureURL" => "http://example.com/img.jpg" }]
            }
          },
          {
            "Reference" => "R456",
            "Type" => "Villa",
            "PropertyType" => { "Type" => "Villa", "OptionValue" => "2" },
            "Location" => "Estepona",
            "Province" => "Malaga",
            "Country" => "Spain",
            "Price" => 750_000,
            "Currency" => "EUR",
            "Bedrooms" => 4,
            "Bathrooms" => 3,
            "Built" => 250,
            "Description" => "Beautiful villa"
          }
        ]
      }.to_json
    end

    before do
      stub_request(:get, /webservice\.resales-online\.com/)
        .to_return(status: 200, body: api_response, headers: { "Content-Type" => "application/json" })
    end

    it "returns NormalizedSearchResult" do
      result = provider.search({})
      expect(result).to be_a(Pwb::ExternalFeed::NormalizedSearchResult)
    end

    it "normalizes properties from API response" do
      result = provider.search({})
      expect(result.properties.length).to eq(2)
      expect(result.properties.first.reference).to eq("R123")
      expect(result.properties.first.bedrooms).to eq(2)
    end

    it "sets total_count from API" do
      result = provider.search({})
      expect(result.total_count).to eq(2)
    end

    it "uses V6 API for sales" do
      provider.search(listing_type: :sale)
      expect(WebMock).to have_requested(:get, /SearchV6/)
    end

    it "uses V5-2 API for rentals" do
      provider.search(listing_type: :rental)
      expect(WebMock).to have_requested(:get, /SearchV5-2/)
    end

    context "when API returns error status" do
      before do
        error_response = { "transaction" => { "status" => "error", "message" => "API Error" } }.to_json
        stub_request(:get, /webservice\.resales-online\.com/)
          .to_return(status: 200, body: error_response, headers: { "Content-Type" => "application/json" })
      end

      it "raises error" do
        expect { provider.search({}) }.to raise_error(Pwb::ExternalFeed::Error)
      end
    end

    context "when API returns single property (not array)" do
      let(:single_property_response) do
        {
          "transaction" => { "status" => "success" },
          "QueryInfo" => { "PropertyCount" => 1 },
          "Property" => {
            "Reference" => "SINGLE1",
            "Type" => "Apartment",
            "PropertyType" => { "Type" => "Apartment" },
            "Location" => "Marbella",
            "Price" => 200_000
          }
        }.to_json
      end

      before do
        stub_request(:get, /webservice\.resales-online\.com/)
          .to_return(status: 200, body: single_property_response, headers: { "Content-Type" => "application/json" })
      end

      it "handles single property as array" do
        result = provider.search({})
        expect(result.properties.length).to eq(1)
        expect(result.properties.first.reference).to eq("SINGLE1")
      end
    end
  end

  describe "#find" do
    let(:property_response) do
      {
        "Property" => {
          "Reference" => "R123",
          "Type" => "Apartment",
          "PropertyType" => { "Type" => "Apartment" },
          "Location" => "Marbella",
          "Province" => "Malaga",
          "Price" => 350_000,
          "Currency" => "EUR",
          "Bedrooms" => 2,
          "Bathrooms" => 1,
          "Built" => 85,
          "Description" => "Nice apartment",
          "Status" => { "system" => "Available" }
        }
      }.to_json
    end

    before do
      stub_request(:get, /webservice\.resales-online\.com/)
        .to_return(status: 200, body: property_response, headers: { "Content-Type" => "application/json" })
    end

    it "returns NormalizedProperty for found property" do
      property = provider.find("R123")
      expect(property).to be_a(Pwb::ExternalFeed::NormalizedProperty)
      expect(property.reference).to eq("R123")
    end

    context "when property not found" do
      let(:empty_response) do
        { "Property" => nil }.to_json
      end

      before do
        stub_request(:get, /webservice\.resales-online\.com/)
          .to_return(status: 200, body: empty_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns nil" do
        expect(provider.find("NONEXISTENT")).to be_nil
      end
    end
  end

  describe "#similar" do
    let(:property) do
      Pwb::ExternalFeed::NormalizedProperty.new(
        reference: "R123",
        city: "Marbella",
        property_type: :apartment,
        bedrooms: 2,
        price: 35_000_000 # In cents
      )
    end

    let(:similar_response) do
      {
        "transaction" => { "status" => "success" },
        "QueryInfo" => { "PropertyCount" => 2 },
        "Property" => [
          { "Reference" => "SIM1", "Type" => "Apartment", "PropertyType" => { "Type" => "Apartment" }, "Location" => "Marbella", "Price" => 340_000 },
          { "Reference" => "SIM2", "Type" => "Apartment", "PropertyType" => { "Type" => "Apartment" }, "Location" => "Marbella", "Price" => 360_000 }
        ]
      }.to_json
    end

    before do
      stub_request(:get, /webservice\.resales-online\.com/)
        .to_return(status: 200, body: similar_response, headers: { "Content-Type" => "application/json" })
    end

    it "returns array of similar properties" do
      similar = provider.similar(property, limit: 4)
      expect(similar).to be_an(Array)
      expect(similar.length).to eq(2)
    end

    it "excludes the original property" do
      similar = provider.similar(property, limit: 4)
      refs = similar.map(&:reference)
      expect(refs).not_to include("R123")
    end
  end

  describe "#locations" do
    it "returns default Costa del Sol locations" do
      locations = provider.locations
      expect(locations).to be_an(Array)
      expect(locations.first).to have_key(:value)
      expect(locations.first).to have_key(:label)
    end

    it "includes common Costa del Sol areas" do
      locations = provider.locations
      location_values = locations.pluck(:value)
      expect(location_values).to include("Marbella")
      expect(location_values).to include("Estepona")
      expect(location_values).to include("Mijas")
    end
  end

  describe "#property_types" do
    it "returns normalized property types" do
      types = provider.property_types
      expect(types).to be_an(Array)
      expect(types.first).to have_key(:value)
      expect(types.first).to have_key(:label)
    end
  end

  describe "#available?" do
    context "with valid credentials" do
      before do
        stub_request(:get, /webservice\.resales-online\.com/)
          .to_return(status: 200, body: '{"transaction":{"status":"success"},"QueryInfo":{"PropertyCount":0}}', headers: { "Content-Type" => "application/json" })
      end

      it "returns true" do
        expect(provider.available?).to be true
      end
    end

    context "when API is unreachable" do
      before do
        stub_request(:get, /webservice\.resales-online\.com/)
          .to_timeout
      end

      it "returns false" do
        expect(provider.available?).to be false
      end
    end
  end

  describe "language mapping" do
    it "maps locale to Resales Online language code" do
      lang = provider.send(:lang_code_for, :en)
      expect(lang).to eq("1")

      lang_es = provider.send(:lang_code_for, :es)
      expect(lang_es).to eq("2")
    end
  end

  describe "property type normalization" do
    it "normalizes Resales property types to standard types" do
      type = provider.send(:normalize_type, "Apartment")
      expect(type).to eq("apartment")

      type = provider.send(:normalize_type, "Detached Villa")
      expect(type).to eq("villa")

      type = provider.send(:normalize_type, "Town House")
      expect(type).to eq("townhouse")
    end
  end
end
