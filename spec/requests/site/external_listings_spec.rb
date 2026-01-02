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
        elsif reference == "RENT1"
          Pwb::ExternalFeed::NormalizedProperty.new(
            reference: reference,
            title: "Test Rental Apartment",
            price: 1500,
            currency: "EUR",
            bedrooms: 2,
            bathrooms: 1,
            status: :available,
            listing_type: :rental
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

  # ============================================
  # New URL Structure Tests
  # ============================================

  describe "GET /external/buy" do
    it "returns success" do
      get external_buy_path
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      get external_buy_path
      expect(response).to render_template(:index)
    end

    it "sets listing_type to :sale" do
      get external_buy_path
      expect(assigns(:listing_type)).to eq(:sale)
    end

    it "assigns search results" do
      get external_buy_path
      expect(assigns(:result)).to be_a(Pwb::ExternalFeed::NormalizedSearchResult)
      expect(assigns(:result).properties.first.reference).to eq("TEST1")
    end

    it "assigns filter options" do
      get external_buy_path
      expect(assigns(:filter_options)).to be_a(Hash)
      expect(assigns(:filter_options)[:locations]).to be_present
    end

    context "with search parameters" do
      it "accepts location parameter" do
        get external_buy_path(location: "marbella")
        expect(response).to have_http_status(:success)
        expect(assigns(:search_params)[:location]).to eq("marbella")
      end

      it "accepts price range parameters" do
        get external_buy_path(min_price: 100_000, max_price: 500_000)
        expect(response).to have_http_status(:success)
      end
    end

    context "with JSON format" do
      it "returns JSON response" do
        get external_buy_path(format: :json)
        expect(response.content_type).to include("application/json")
      end
    end

    context "when feed is not configured" do
      before do
        website.update!(external_feed_enabled: false)
      end

      it "redirects to root" do
        get external_buy_path
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("/")
      end

      it "sets flash alert" do
        get external_buy_path
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "GET /external/rent" do
    it "returns success" do
      get external_rent_path
      expect(response).to have_http_status(:success)
    end

    it "renders the index template" do
      get external_rent_path
      expect(response).to render_template(:index)
    end

    it "sets listing_type to :rental" do
      get external_rent_path
      expect(assigns(:listing_type)).to eq(:rental)
    end

    it "assigns search results with rental type" do
      get external_rent_path
      expect(assigns(:result)).to be_a(Pwb::ExternalFeed::NormalizedSearchResult)
      expect(assigns(:search_params)[:listing_type]).to eq(:rental)
    end

    context "when feed is not configured" do
      before do
        website.update!(external_feed_enabled: false)
      end

      it "redirects to root" do
        get external_rent_path
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe "GET /external/for-sale/:reference/:url_friendly_title" do
    it "returns success for existing property" do
      get external_show_for_sale_path(reference: "TEST1", url_friendly_title: "test-villa")
      expect(response).to have_http_status(:success)
    end

    it "renders show template" do
      get external_show_for_sale_path(reference: "TEST1", url_friendly_title: "test-villa")
      expect(response).to render_template(:show)
    end

    it "assigns the listing" do
      get external_show_for_sale_path(reference: "TEST1", url_friendly_title: "test-villa")
      expect(assigns(:listing)).to be_a(Pwb::ExternalFeed::NormalizedProperty)
      expect(assigns(:listing).reference).to eq("TEST1")
    end

    it "sets listing_type to :sale" do
      get external_show_for_sale_path(reference: "TEST1", url_friendly_title: "test-villa")
      expect(assigns(:listing_type)).to eq(:sale)
    end

    it "assigns similar properties" do
      get external_show_for_sale_path(reference: "TEST1", url_friendly_title: "test-villa")
      expect(assigns(:similar)).to be_an(Array)
    end

    context "when property not found" do
      it "returns 404" do
        get external_show_for_sale_path(reference: "NONEXISTENT", url_friendly_title: "property")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when property is sold" do
      it "returns 410 Gone" do
        get external_show_for_sale_path(reference: "SOLD1", url_friendly_title: "sold-property")
        expect(response).to have_http_status(:gone)
      end

      it "renders unavailable template" do
        get external_show_for_sale_path(reference: "SOLD1", url_friendly_title: "sold-property")
        expect(response).to render_template(:unavailable)
      end

      it "sets status message" do
        get external_show_for_sale_path(reference: "SOLD1", url_friendly_title: "sold-property")
        expect(assigns(:status_message)).to be_present
      end
    end

    context "with JSON format" do
      it "returns JSON response" do
        get external_show_for_sale_path(reference: "TEST1", url_friendly_title: "test-villa", format: :json)
        expect(response.content_type).to include("application/json")
      end
    end
  end

  describe "GET /external/for-rent/:reference/:url_friendly_title" do
    it "returns success for existing rental property" do
      get external_show_for_rent_path(reference: "RENT1", url_friendly_title: "test-rental-apartment")
      expect(response).to have_http_status(:success)
    end

    it "renders show template" do
      get external_show_for_rent_path(reference: "RENT1", url_friendly_title: "test-rental-apartment")
      expect(response).to render_template(:show)
    end

    it "sets listing_type to :rental" do
      get external_show_for_rent_path(reference: "RENT1", url_friendly_title: "test-rental-apartment")
      expect(assigns(:listing_type)).to eq(:rental)
    end

    context "when property not found" do
      it "returns 404" do
        get external_show_for_rent_path(reference: "NONEXISTENT", url_friendly_title: "property")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ============================================
  # Legacy URL Redirect Tests
  # ============================================

  describe "GET /external_listings (legacy)" do
    it "redirects to /external/buy with 301" do
      get "/external_listings"
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to include("/external/buy")
    end

    it "redirects to /external/rent when listing_type is rental" do
      get "/external_listings", params: { listing_type: "rental" }
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to include("/external/rent")
    end

    it "preserves search parameters in redirect" do
      get "/external_listings", params: { location: "marbella", min_price: 100_000 }
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to include("location=marbella")
      expect(response.location).to include("min_price=100000")
    end
  end

  describe "GET /external_listings/search (legacy)" do
    it "redirects to /external/buy with 301" do
      get "/external_listings/search"
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to include("/external/buy")
    end

    it "redirects to /external/rent when listing_type is rental" do
      get "/external_listings/search", params: { listing_type: "rental" }
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to include("/external/rent")
    end
  end

  describe "GET /external_listings/:reference (legacy)" do
    it "redirects to new for-sale URL pattern with 301" do
      get "/external_listings/TEST1"
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to include("/external/for-sale/TEST1/")
    end

    it "redirects to new for-rent URL pattern for rental properties" do
      get "/external_listings/RENT1"
      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to include("/external/for-rent/RENT1/")
    end

    context "when property not found" do
      it "returns 404" do
        get "/external_listings/NONEXISTENT"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ============================================
  # API Endpoint Tests (unchanged paths)
  # ============================================

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
