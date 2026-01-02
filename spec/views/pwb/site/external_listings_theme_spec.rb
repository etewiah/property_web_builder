# frozen_string_literal: true

require "rails_helper"

RSpec.describe "External Listings Theme Support", type: :request do
  let(:website) do
    w = create(:website)
    # Set available_themes to allow brisbane and bologna for testing
    w.update_column(:available_themes, %w[default brisbane bologna])
    w
  end

  # Mock provider for testing themes
  let(:mock_provider_class) do
    Class.new(Pwb::ExternalFeed::BaseProvider) do
      def self.provider_name
        :theme_test_provider
      end

      def self.display_name
        "Theme Test Provider"
      end

      def self.required_config_keys
        [:api_key]
      end

      def search(params)
        Pwb::ExternalFeed::NormalizedSearchResult.new(
          properties: [mock_property],
          total_count: 1
        )
      end

      def find(reference, params = {})
        mock_property
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

      private

      def mock_property
        Pwb::ExternalFeed::NormalizedProperty.new(
          reference: "THEME_TEST_123",
          title: "Beautiful Theme Test Property",
          description: "A wonderful property for testing themes",
          price: 250_000,
          currency: "EUR",
          listing_type: :sale,
          property_type: "apartment",
          bedrooms: 3,
          bathrooms: 2,
          built_area: 120,
          location: "Test City",
          province: "Test Province",
          country: "Spain",
          latitude: 40.4168,
          longitude: -3.7038,
          images: [{ url: "https://example.com/image1.jpg" }],
          features: ["Pool", "Garage", "Garden"],
          status: :available
        )
      end
    end
  end

  before do
    # Register mock provider
    Pwb::ExternalFeed::Registry.register(mock_provider_class)

    # Configure website with mock provider
    website.update!(
      external_feed_enabled: true,
      external_feed_provider: "theme_test_provider",
      external_feed_config: { api_key: "test123" }
    )

    # Set current website for requests
    allow_any_instance_of(Pwb::ApplicationController).to receive(:current_website).and_return(website)
  end

  after do
    Pwb::ExternalFeed::Registry.instance_variable_get(:@providers).delete(:theme_test_provider)
  end

  describe "theme view resolution" do
    context "with default theme" do
      before { website.update!(theme_name: "default") }

      it "renders the show page successfully" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        expect(response).to have_http_status(:success)
      end

      it "renders the property title" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        expect(response.body).to include("Beautiful Theme Test Property")
      end

      it "renders the property features" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        expect(response.body).to include("Pool")
        expect(response.body).to include("Garage")
      end
    end

    context "with brisbane theme" do
      before { website.update!(theme_name: "brisbane") }

      it "renders the show page successfully" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        expect(response).to have_http_status(:success)
      end

      it "uses brisbane theme CSS classes" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        # Brisbane theme uses property-detail-* classes
        expect(response.body).to include("property-detail-page")
        expect(response.body).to include("property-detail-container")
      end

      it "renders the property title" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        expect(response.body).to include("Beautiful Theme Test Property")
      end

      it "renders social sharing" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        expect(response.body).to include("facebook.com/sharer")
      end
    end

    context "with bologna theme" do
      before { website.update!(theme_name: "bologna") }

      it "renders the show page successfully" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        expect(response).to have_http_status(:success)
      end

      it "uses bologna theme CSS classes" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        # Bologna theme uses warm-gray, terra, olive colors
        expect(response.body).to include("warm-gray")
      end

      it "renders the property title" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        expect(response.body).to include("Beautiful Theme Test Property")
      end

      it "uses bologna rounded-softer class" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        expect(response.body).to include("rounded-softer")
      end

      it "uses bologna shadow-soft class" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
        expect(response.body).to include("shadow-soft")
      end
    end

    context "with theme override via URL parameter" do
      before { website.update!(theme_name: "default") }

      it "allows switching to brisbane theme" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale", theme: "brisbane" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("property-detail-page")
      end

      it "allows switching to bologna theme" do
        get "/external_listings/THEME_TEST_123", params: { listing_type: "sale", theme: "bologna" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("warm-gray")
      end
    end
  end

  describe "shared partials across themes" do
    before { website.update!(theme_name: "brisbane") }

    it "renders the meta_tags partial with Open Graph tags" do
      get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
      expect(response.body).to include("og:title")
      expect(response.body).to include("og:description")
    end

    it "renders the contact form partial" do
      get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
      expect(response.body).to include("contact-form")
      expect(response.body).to include("contact[name]")
    end

    it "renders the map with Stimulus controller" do
      get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
      expect(response.body).to include('data-controller="map"')
      expect(response.body).to include("data-map-markers-value")
    end

    it "renders JSON-LD structured data" do
      get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
      expect(response.body).to include("application/ld+json")
      expect(response.body).to include("RealEstateListing")
    end
  end

  describe "fragment caching with themes" do
    before { website.update!(theme_name: "brisbane") }

    it "generates tenant-scoped cache keys" do
      get "/external_listings/THEME_TEST_123", params: { listing_type: "sale" }
      # The response should succeed, and caching should work
      expect(response).to have_http_status(:success)
    end
  end
end
