# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pwb::ExternalFeed::Registry do
  # Create a mock provider for testing
  let(:mock_provider_class) do
    Class.new(Pwb::ExternalFeed::BaseProvider) do
      def self.provider_name
        :mock_provider
      end

      def self.display_name
        "Mock Provider"
      end

      def self.required_config_keys
        [:api_key]
      end

      def search(params)
        Pwb::ExternalFeed::NormalizedSearchResult.new(properties: [], total_count: 0)
      end

      def find(reference, params = {})
        nil
      end

      def similar(property, params = {})
        []
      end

      def locations(params = {})
        []
      end

      def property_types(params = {})
        []
      end

      def available?
        true
      end
    end
  end

  before do
    # Clear registry before each test
    described_class.instance_variable_set(:@providers, {})
  end

  describe ".register" do
    it "registers a provider class" do
      described_class.register(mock_provider_class)
      expect(described_class.available_providers).to include(:mock_provider)
    end

    it "allows registering multiple providers" do
      described_class.register(mock_provider_class)

      another_provider = Class.new(mock_provider_class) do
        def self.provider_name
          :another_provider
        end
      end

      described_class.register(another_provider)
      expect(described_class.available_providers).to contain_exactly(:mock_provider, :another_provider)
    end
  end

  describe ".find" do
    before do
      described_class.register(mock_provider_class)
    end

    it "finds a registered provider by name (symbol)" do
      expect(described_class.find(:mock_provider)).to eq(mock_provider_class)
    end

    it "finds a registered provider by name (string)" do
      expect(described_class.find("mock_provider")).to eq(mock_provider_class)
    end

    it "returns nil for unregistered providers" do
      expect(described_class.find(:unknown_provider)).to be_nil
    end
  end

  describe ".available_providers" do
    it "returns empty array when no providers registered" do
      expect(described_class.available_providers).to eq([])
    end

    it "returns list of registered provider names" do
      described_class.register(mock_provider_class)
      expect(described_class.available_providers).to eq([:mock_provider])
    end
  end

  describe ".registered?" do
    before do
      described_class.register(mock_provider_class)
    end

    it "returns true for registered providers" do
      expect(described_class.registered?(:mock_provider)).to be true
    end

    it "returns false for unregistered providers" do
      expect(described_class.registered?(:unknown)).to be false
    end
  end
end
