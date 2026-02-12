# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiManage::V1::SppListings#update', type: :request do
  let!(:website) { create(:pwb_website) }
  let!(:user) { create(:pwb_user, :admin, website: website) }
  let!(:property) { create(:pwb_realty_asset, website: website) }
  let!(:spp_listing) do
    create(:pwb_spp_listing, :published,
           realty_asset: property,
           listing_type: 'sale')
  end

  let(:auth_headers) do
    {
      'HTTP_HOST' => "#{website.subdomain}.localhost",
      'X-User-Email' => user.email
    }
  end

  let(:endpoint) { "/api_manage/v1/en/spp_listings/#{spp_listing.id}" }

  before do
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  # ============================================
  # Basic Content Updates
  # ============================================
  describe 'updating translated fields' do
    it 'updates title via Mobility in the specified locale' do
      put endpoint, params: { title: 'Your Dream Mediterranean Retreat' }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['title']).to eq('Your Dream Mediterranean Retreat')

      spp_listing.reload
      Mobility.with_locale(:en) do
        expect(spp_listing.title).to eq('Your Dream Mediterranean Retreat')
      end
    end

    it 'stores translations in the correct locale' do
      put "/api_manage/v1/es/spp_listings/#{spp_listing.id}",
          params: { title: 'Tu Refugio Mediterraneo' },
          headers: auth_headers

      expect(response).to have_http_status(:ok)

      spp_listing.reload
      Mobility.with_locale(:es) do
        expect(spp_listing.title).to eq('Tu Refugio Mediterraneo')
      end
    end

    it 'updates description and SEO fields' do
      put endpoint, params: {
        description: 'Imagine waking up to the sound of waves...',
        seo_title: 'Luxury Biarritz Apartment',
        meta_description: 'Stunning 3-bed apartment in Biarritz...'
      }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['description']).to eq('Imagine waking up to the sound of waves...')
      expect(json['seoTitle']).to eq('Luxury Biarritz Apartment')
      expect(json['metaDescription']).to eq('Stunning 3-bed apartment in Biarritz...')
    end
  end

  # ============================================
  # Price Updates
  # ============================================
  describe 'updating price' do
    it 'updates price_cents and price_currency' do
      put endpoint, params: { price_cents: 550_000_00, price_currency: 'USD' }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['priceCents']).to eq(550_000_00)
      expect(json['priceCurrency']).to eq('USD')
    end
  end

  # ============================================
  # Photo IDs Ordered
  # ============================================
  describe 'updating photo_ids_ordered' do
    let!(:photo1) { create(:pwb_prop_photo, realty_asset: property, sort_order: 1) }
    let!(:photo2) { create(:pwb_prop_photo, realty_asset: property, sort_order: 2) }
    let!(:photo3) { create(:pwb_prop_photo, realty_asset: property, sort_order: 3) }

    it 'accepts valid photo IDs belonging to the same property' do
      put endpoint, params: { photo_ids_ordered: [photo3.id, photo1.id] }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['photoIdsOrdered']).to eq([photo3.id, photo1.id])
    end

    it 'rejects photo IDs from a different property' do
      other_property = create(:pwb_realty_asset, website: website)
      other_photo = create(:pwb_prop_photo, realty_asset: other_property)

      put endpoint, params: { photo_ids_ordered: [photo1.id, other_photo.id] }, headers: auth_headers

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json['error']).to eq('Invalid photo IDs')
      expect(json['message']).to include(other_photo.id.to_s)
    end

    it 'accepts an empty array to reset to default order' do
      spp_listing.update!(photo_ids_ordered: [photo2.id, photo1.id])

      put endpoint, params: { photo_ids_ordered: [] }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['photoIdsOrdered']).to eq([])
    end
  end

  # ============================================
  # Highlighted Features
  # ============================================
  describe 'updating highlighted_features' do
    it 'accepts an array of feature keys' do
      put endpoint, params: { highlighted_features: %w[sea_views private_pool parking] }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['highlightedFeatures']).to eq(%w[sea_views private_pool parking])
    end
  end

  # ============================================
  # Template and Settings
  # ============================================
  describe 'updating template and spp_settings' do
    it 'updates the template' do
      put endpoint, params: { template: 'modern' }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['template']).to eq('modern')
    end

    it 'updates spp_settings' do
      put endpoint, params: { spp_settings: { color_scheme: 'dark', layout: 'full-width' } }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['sppSettings']).to eq({ 'color_scheme' => 'dark', 'layout' => 'full-width' })
    end
  end

  # ============================================
  # Extra Data (Arbitrary JSON)
  # ============================================
  describe 'updating extra_data' do
    it 'accepts arbitrary JSON' do
      extra = {
        agent_name: 'Marie Dupont',
        agent_phone: '+33 6 12 34 56 78',
        video_tour_url: 'https://youtube.com/watch?v=abc123'
      }

      put endpoint, params: { extra_data: extra }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['extraData']['agent_name']).to eq('Marie Dupont')
      expect(json['extraData']['video_tour_url']).to eq('https://youtube.com/watch?v=abc123')
    end
  end

  # ============================================
  # Response Format
  # ============================================
  describe 'response format' do
    it 'returns the full SppListing JSON' do
      put endpoint, params: { title: 'Updated Title' }, headers: auth_headers

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to include(
        'id', 'listingType', 'title', 'description',
        'seoTitle', 'metaDescription', 'priceCents', 'priceCurrency',
        'photoIdsOrdered', 'highlightedFeatures', 'template',
        'sppSettings', 'extraData', 'active', 'visible',
        'liveUrl', 'publishedAt', 'updatedAt'
      )
    end
  end

  # ============================================
  # Authentication & Authorization
  # ============================================
  describe 'authentication' do
    it 'returns 401 without authentication' do
      put endpoint, params: { title: 'Test' },
                    headers: { 'HTTP_HOST' => "#{website.subdomain}.localhost" }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ============================================
  # Tenant Isolation
  # ============================================
  describe 'tenant isolation' do
    it 'returns 404 for SppListings belonging to other tenants' do
      other_website = create(:pwb_website, subdomain: 'other-tenant')
      other_property = create(:pwb_realty_asset, website: other_website)
      other_listing = create(:pwb_spp_listing, :published, realty_asset: other_property)

      put "/api_manage/v1/en/spp_listings/#{other_listing.id}",
          params: { title: 'Hijack attempt' },
          headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  # ============================================
  # Not Found
  # ============================================
  describe 'non-existent listing' do
    it 'returns 404 for unknown IDs' do
      put '/api_manage/v1/en/spp_listings/00000000-0000-0000-0000-000000000000',
          params: { title: 'Test' },
          headers: auth_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
