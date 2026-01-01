# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::ExternalFeed::Manager do
  let(:website) { create(:website) }
  let(:manager) { described_class.new(website) }

  # Mock provider for testing
  let(:mock_provider_class) do
    Class.new(Pwb::ExternalFeed::BaseProvider) do
      def self.provider_name
        :test_provider
      end

      def self.display_name
        "Test Provider"
      end

      def self.required_config_keys
        [:api_key]
      end

      def search(params)
        Pwb::ExternalFeed::NormalizedSearchResult.new(
          properties: [
            Pwb::ExternalFeed::NormalizedProperty.new(reference: "TEST1", title: "Test Property")
          ],
          total_count: 1
        )
      end

      def find(reference, params = {})
        Pwb::ExternalFeed::NormalizedProperty.new(reference: reference, title: "Found Property")
      end

      def similar(property, params = {})
        [Pwb::ExternalFeed::NormalizedProperty.new(reference: "SIM1", title: "Similar")]
      end

      def locations(params = {})
        [{ value: "loc1", label: "Location 1" }]
      end

      def property_types(params = {})
        [{ value: "apartment", label: "Apartment" }]
      end

      def available?
        true
      end
    end
  end

  before do
    # Register mock provider
    Pwb::ExternalFeed::Registry.register(mock_provider_class)
  end

  after do
    # Clean up registry
    Pwb::ExternalFeed::Registry.instance_variable_get(:@providers).delete(:test_provider)
  end

  describe "#configured?" do
    context "when external feed is enabled with valid provider" do
      before do
        website.update!(
          external_feed_enabled: true,
          external_feed_provider: "test_provider",
          external_feed_config: { api_key: "test123" }
        )
      end

      it "returns true" do
        expect(manager.configured?).to be true
      end
    end

    context "when external feed is disabled" do
      before do
        website.update!(external_feed_enabled: false)
      end

      it "returns false" do
        expect(manager.configured?).to be false
      end
    end

    context "when provider is not set" do
      before do
        website.update!(
          external_feed_enabled: true,
          external_feed_provider: nil
        )
      end

      it "returns false" do
        expect(manager.configured?).to be false
      end
    end

    context "when provider is not registered" do
      before do
        website.update!(
          external_feed_enabled: true,
          external_feed_provider: "unknown_provider"
        )
      end

      it "returns false" do
        expect(manager.configured?).to be false
      end
    end
  end

  describe "#enabled?" do
    context "when configured and provider is available" do
      before do
        website.update!(
          external_feed_enabled: true,
          external_feed_provider: "test_provider",
          external_feed_config: { api_key: "test123" }
        )
      end

      it "returns true" do
        expect(manager.enabled?).to be true
      end
    end

    context "when not configured" do
      before do
        website.update!(external_feed_enabled: false)
      end

      it "returns false" do
        expect(manager.enabled?).to be false
      end
    end
  end

  describe "#search" do
    before do
      website.update!(
        external_feed_enabled: true,
        external_feed_provider: "test_provider",
        external_feed_config: { api_key: "test123" }
      )
    end

    it "returns search results from provider" do
      result = manager.search({})
      expect(result).to be_a(Pwb::ExternalFeed::NormalizedSearchResult)
      expect(result.properties.first.reference).to eq("TEST1")
    end

    context "when not configured" do
      before do
        website.update!(external_feed_enabled: false)
      end

      it "returns empty result with error" do
        result = manager.search({})
        expect(result.empty?).to be true
        expect(result.error?).to be true
      end
    end
  end

  describe "#find" do
    before do
      website.update!(
        external_feed_enabled: true,
        external_feed_provider: "test_provider",
        external_feed_config: { api_key: "test123" }
      )
    end

    it "returns property from provider" do
      property = manager.find("REF123")
      expect(property).to be_a(Pwb::ExternalFeed::NormalizedProperty)
      expect(property.reference).to eq("REF123")
    end

    context "when not configured" do
      before do
        website.update!(external_feed_enabled: false)
      end

      it "returns nil" do
        expect(manager.find("REF123")).to be_nil
      end
    end
  end

  describe "#similar" do
    let(:property) do
      Pwb::ExternalFeed::NormalizedProperty.new(reference: "REF123", title: "Test")
    end

    before do
      website.update!(
        external_feed_enabled: true,
        external_feed_provider: "test_provider",
        external_feed_config: { api_key: "test123" }
      )
    end

    it "returns similar properties from provider" do
      similar = manager.similar(property)
      expect(similar).to be_an(Array)
      expect(similar.first.reference).to eq("SIM1")
    end
  end

  describe "#locations" do
    before do
      website.update!(
        external_feed_enabled: true,
        external_feed_provider: "test_provider",
        external_feed_config: { api_key: "test123" }
      )
    end

    it "returns locations from provider" do
      locations = manager.locations
      expect(locations).to be_an(Array)
      expect(locations.first[:value]).to eq("loc1")
    end
  end

  describe "#property_types" do
    before do
      website.update!(
        external_feed_enabled: true,
        external_feed_provider: "test_provider",
        external_feed_config: { api_key: "test123" }
      )
    end

    it "returns property types from provider" do
      types = manager.property_types
      expect(types).to be_an(Array)
      expect(types.first[:value]).to eq("apartment")
    end
  end

  describe "#filter_options" do
    before do
      website.update!(
        external_feed_enabled: true,
        external_feed_provider: "test_provider",
        external_feed_config: { api_key: "test123" }
      )
    end

    it "returns combined filter options" do
      options = manager.filter_options
      expect(options).to have_key(:locations)
      expect(options).to have_key(:property_types)
      expect(options).to have_key(:sort_options)
    end
  end

  describe "#invalidate_cache" do
    before do
      website.update!(
        external_feed_enabled: true,
        external_feed_provider: "test_provider",
        external_feed_config: { api_key: "test123" }
      )
    end

    it "clears the cache for this website" do
      expect { manager.invalidate_cache }.not_to raise_error
    end
  end
end
