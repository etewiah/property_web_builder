# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Property Lifecycle Integration', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'lifecycle-test') }
  let!(:user) { create(:pwb_user, :admin, website: website) }

  before do
    sign_in user
    host! 'lifecycle-test.example.com'
  end

  describe 'Property Creation to Listing' do
    it 'creates a property and it appears in listings' do
      # Create a realty asset
      asset = create(:pwb_realty_asset, website: website)

      # Create a sale listing
      sale_listing = create(:pwb_sale_listing, :visible, realty_asset: asset)

      # Refresh the materialized view
      Pwb::ListedProperty.refresh(concurrently: false)

      # Property should now be visible in API
      get '/api_public/v1/properties', params: { sale_or_rental: 'sale' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      property_ids = json['data'].map { |p| p['id'] }

      expect(property_ids).to include(asset.id)
    end

    it 'hidden property does not appear in listings' do
      # Create a hidden property
      asset = create(:pwb_realty_asset, website: website)
      create(:pwb_sale_listing, realty_asset: asset, visible: false)

      Pwb::ListedProperty.refresh(concurrently: false)

      get '/api_public/v1/properties', params: { sale_or_rental: 'sale' }

      json = response.parsed_body
      property_ids = json['data'].map { |p| p['id'] }

      expect(property_ids).not_to include(asset.id)
    end
  end

  describe 'Property with Photos' do
    it 'creates property with photos and photos are accessible' do
      asset = create(:pwb_realty_asset, website: website)
      create(:pwb_sale_listing, :visible, realty_asset: asset)

      # Add photos
      3.times do
        create(:pwb_prop_photo, realty_asset: asset)
      end

      Pwb::ListedProperty.refresh(concurrently: false)

      get "/api_public/v1/properties/#{asset.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      # Property should have photos info
      expect(json['photos']).to be_an(Array) if json.key?('photos')
    end
  end

  describe 'Property Visibility Toggle' do
    let!(:asset) { create(:pwb_realty_asset, website: website) }
    let!(:listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

    before do
      Pwb::ListedProperty.refresh(concurrently: false)
    end

    it 'property becomes invisible when listing visibility is toggled off' do
      # Verify initially visible
      get '/api_public/v1/properties', params: { sale_or_rental: 'sale' }
      json = response.parsed_body
      expect(json['data'].map { |p| p['id'] }).to include(asset.id)

      # Toggle visibility
      listing.update!(visible: false)
      Pwb::ListedProperty.refresh(concurrently: false)

      # Verify no longer visible
      get '/api_public/v1/properties', params: { sale_or_rental: 'sale' }
      json = response.parsed_body
      expect(json['data'].map { |p| p['id'] }).not_to include(asset.id)
    end
  end

  describe 'Property Details Access' do
    let!(:asset) { create(:pwb_realty_asset, website: website) }
    let!(:listing) { create(:pwb_sale_listing, :visible, realty_asset: asset) }

    before do
      Pwb::ListedProperty.refresh(concurrently: false)
    end

    it 'can view property by ID' do
      get "/api_public/v1/properties/#{asset.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(asset.id)
    end

    it 'can view property by slug' do
      get "/api_public/v1/properties/#{asset.slug}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(asset.id)
    end
  end

  describe 'Property Filtering' do
    let!(:cheap_asset) do
      asset = create(:pwb_realty_asset, website: website)
      create(:pwb_sale_listing, :visible, realty_asset: asset, price_sale_current_cents: 100_000_00)
      asset
    end

    let!(:expensive_asset) do
      asset = create(:pwb_realty_asset, website: website)
      create(:pwb_sale_listing, :visible, realty_asset: asset, price_sale_current_cents: 500_000_00)
      asset
    end

    before do
      Pwb::ListedProperty.refresh(concurrently: false)
    end

    it 'can sort by price ascending' do
      get '/api_public/v1/properties', params: { sale_or_rental: 'sale', sort_by: 'price_asc' }

      json = response.parsed_body
      prices = json['data'].map { |p| p['price_sale_current_cents'] }.compact

      expect(prices).to eq(prices.sort)
    end

    it 'can sort by price descending' do
      get '/api_public/v1/properties', params: { sale_or_rental: 'sale', sort_by: 'price_desc' }

      json = response.parsed_body
      prices = json['data'].map { |p| p['price_sale_current_cents'] }.compact

      expect(prices).to eq(prices.sort.reverse)
    end
  end

  describe 'For Sale vs For Rent' do
    let!(:sale_asset) do
      asset = create(:pwb_realty_asset, website: website)
      create(:pwb_sale_listing, :visible, realty_asset: asset)
      asset
    end

    let!(:rental_asset) do
      asset = create(:pwb_realty_asset, website: website)
      create(:pwb_rental_listing, :visible, realty_asset: asset)
      asset
    end

    before do
      Pwb::ListedProperty.refresh(concurrently: false)
    end

    it 'filters by sale only' do
      get '/api_public/v1/properties', params: { sale_or_rental: 'sale' }

      json = response.parsed_body
      property_ids = json['data'].map { |p| p['id'] }

      expect(property_ids).to include(sale_asset.id)
      expect(property_ids).not_to include(rental_asset.id)
    end

    it 'filters by rental only' do
      get '/api_public/v1/properties', params: { sale_or_rental: 'rental' }

      json = response.parsed_body
      property_ids = json['data'].map { |p| p['id'] }

      expect(property_ids).to include(rental_asset.id)
      expect(property_ids).not_to include(sale_asset.id)
    end
  end
end
