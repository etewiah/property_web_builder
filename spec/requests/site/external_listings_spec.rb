# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Site::ExternalListings", type: :request do
  let(:website) { create(:website) }

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
            Pwb::ExternalFeed::NormalizedProperty.new(
              reference: "TEST1",
              title: "Test Villa",
              price: 500_000,
              currency: "EUR",
              bedrooms: 3,
              bathrooms: 2,
              listing_type: params[:listing_type] || :sale
            )
          ],
          total_count: 1
        )
      end

      def find(reference, params = {})
        if reference == "TEST1"
          Pwb::ExternalFeed::NormalizedProperty.new(
            reference: reference,
            title: "Test Villa",
            price: 500_000,
            currency: "EUR",
            bedrooms: 3,
            bathrooms: 2,
            status: :available,
            listing_type: params[:listing_type] || :sale
          )
        elsif reference == "SOLD1"
          Pwb::ExternalFeed::NormalizedProperty.new(
            reference: reference,
            title: "Sold Property",
            status: :sold,
            listing_type: :sale
          )
        end
      end

      def similar(property, params = {})
        [
          Pwb::ExternalFeed::NormalizedProperty.new(
            reference: "SIM1",
            title: "Similar Property",
            price: 450_000
          )
        ]
      end

      def locations(params = {})
        [{ value: "marbella", label: "Marbella" }]
      end

      def property_types(params = {})
        [{ value: "villa", label: "Villa" }]
      end

      def available?
        true
      end
    end
  end

  before do
    # Register mock provider
    Pwb::ExternalFeed::Registry.register(mock_provider_class)

    # Configure website with mock provider
    website.update!(
      external_feed_enabled: true,
      external_feed_provider: "test_provider",
      external_feed_config: { api_key: "test123" }
    )

    # Set current website for requests
    allow_any_instance_of(Pwb::ApplicationController).to receive(:current_website).and_return(website)
  end

  after do
    Pwb::ExternalFeed::Registry.instance_variable_get(:@providers).delete(:test_provider)
  end

  describe "GET /external_listings" do
    it "returns success" do
      get external_listings_path
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      get external_listings_path
      expect(response).to render_template(:index)
    end

    it "assigns search results" do
      get external_listings_path
      expect(assigns(:result)).to be_a(Pwb::ExternalFeed::NormalizedSearchResult)
      expect(assigns(:result).properties.first.reference).to eq("TEST1")
    end

    it "assigns filter options" do
      get external_listings_path
      expect(assigns(:filter_options)).to be_a(Hash)
      expect(assigns(:filter_options)[:locations]).to be_present
    end

    context "with JSON format" do
      it "returns JSON response" do
        get external_listings_path(format: :json)
        expect(response.content_type).to include("application/json")
      end
    end

    context "when feed is not configured" do
      before do
        website.update!(external_feed_enabled: false)
      end

      it "redirects to root" do
        get external_listings_path
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/")
      end

      it "sets flash alert" do
        get external_listings_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET /external_listings/search" do
    it "returns success" do
      get search_external_listings_path
      expect(response).to have_http_status(:success)
    end

    it "accepts search parameters" do
      get search_external_listings_path(listing_type: "sale", location: "marbella", min_price: 100_000)
      expect(response).to have_http_status(:success)
    end

    it "filters by listing type" do
      get search_external_listings_path(listing_type: "rental")
      expect(assigns(:search_params)[:listing_type]).to eq(:rental)
    end
  end

  describe "GET /external_listings/:reference" do
    it "returns success for existing property" do
      get external_listing_path(reference: "TEST1")
      expect(response).to have_http_status(:success)
    end

    it "renders show template" do
      get external_listing_path(reference: "TEST1")
      expect(response).to render_template(:show)
    end

    it "assigns the listing" do
      get external_listing_path(reference: "TEST1")
      expect(assigns(:listing)).to be_a(Pwb::ExternalFeed::NormalizedProperty)
      expect(assigns(:listing).reference).to eq("TEST1")
    end

    it "assigns similar properties" do
      get external_listing_path(reference: "TEST1")
      expect(assigns(:similar)).to be_an(Array)
    end

    context "when property not found" do
      it "returns 404" do
        get external_listing_path(reference: "NONEXISTENT")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when property is sold" do
      it "returns 410 Gone" do
        get external_listing_path(reference: "SOLD1")
        expect(response).to have_http_status(:gone)
      end

      it "renders unavailable template" do
        get external_listing_path(reference: "SOLD1")
        expect(response).to render_template(:unavailable)
      end

      it "sets status message" do
        get external_listing_path(reference: "SOLD1")
        expect(assigns(:status_message)).to be_present
      end
    end

    context "with JSON format" do
      it "returns JSON response" do
        get external_listing_path(reference: "TEST1", format: :json)
        expect(response.content_type).to include("application/json")
      end
    end
  end

  describe "GET /external_listings/:reference/similar" do
    it "returns success" do
      get similar_external_listing_path(reference: "TEST1")
      expect(response).to have_http_status(:success)
    end

    it "limits results" do
      get similar_external_listing_path(reference: "TEST1", limit: 4)
      expect(response).to have_http_status(:success)
    end

    context "when property not found" do
      it "returns 404 JSON" do
        get similar_external_listing_path(reference: "NONEXISTENT", format: :json)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with JSON format" do
      it "returns array of similar properties" do
        get similar_external_listing_path(reference: "TEST1", format: :json)
        expect(response.content_type).to include("application/json")
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
      end
    end
  end

  describe "GET /external_listings/locations" do
    it "returns JSON with locations" do
      get locations_external_listings_path
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/json")

      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first["value"]).to eq("marbella")
    end
  end

  describe "GET /external_listings/property_types" do
    it "returns JSON with property types" do
      get property_types_external_listings_path
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/json")

      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first["value"]).to eq("villa")
    end
  end

  describe "GET /external_listings/filters" do
    it "returns JSON with filter options" do
      get filters_external_listings_path
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("application/json")

      json = JSON.parse(response.body)
      expect(json).to have_key("locations")
      expect(json).to have_key("property_types")
      expect(json).to have_key("sort_options")
    end
  end
end
