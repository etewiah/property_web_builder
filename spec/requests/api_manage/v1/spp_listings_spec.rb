# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiManage::V1::SppListings', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:website) { create(:pwb_website) }
  let!(:user) { create(:pwb_user, :admin, website: website) }
  let!(:property) { create(:pwb_realty_asset, website: website) }

  let(:auth_headers) do
    {
      'HTTP_HOST' => "#{website.subdomain}.localhost",
      'X-User-Email' => user.email
    }
  end

  before do
    ActsAsTenant.current_tenant = website
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  # ============================================
  # Publish Endpoint
  # ============================================
  describe 'POST /api_manage/v1/:locale/properties/:id/spp_publish' do
    let(:endpoint) { "/api_manage/v1/en/properties/#{property.id}/spp_publish" }
    let(:spp_url_template) { 'https://{slug}-{listing_type}.spp.example.com/' }

    before do
      website.update!(client_theme_config: { 'spp_url_template' => spp_url_template })
    end

    context 'with valid request' do
      it 'creates an SPP listing and returns published status' do
        expect {
          post endpoint, headers: auth_headers, as: :json
        }.to change(Pwb::SppListing, :count).by(1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('published')
        expect(json['listingType']).to eq('sale')
        expect(json['liveUrl']).to include(property.slug)
        expect(json['publishedAt']).to be_present
      end

      it 'defaults to sale listing_type' do
        post endpoint, headers: auth_headers, as: :json
        listing = Pwb::SppListing.last
        expect(listing.listing_type).to eq('sale')
      end

      it 'creates rental listing when specified' do
        post endpoint, params: { listing_type: 'rental' }, headers: auth_headers, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['listingType']).to eq('rental')
      end

      it 'interpolates live_url from spp_url_template' do
        post endpoint, params: { listing_type: 'sale' }, headers: auth_headers, as: :json

        json = JSON.parse(response.body)
        expected_url = "https://#{property.slug}-sale.spp.example.com/"
        expect(json['liveUrl']).to eq(expected_url)
      end

      it 'sets active, visible, and published_at on the listing' do
        post endpoint, headers: auth_headers, as: :json

        listing = Pwb::SppListing.last
        expect(listing).to be_active
        expect(listing).to be_visible
        expect(listing).not_to be_archived
        expect(listing.published_at).to be_within(5.seconds).of(Time.current)
      end
    end

    context 'idempotent re-publish' do
      it 'does not create a duplicate listing' do
        post endpoint, headers: auth_headers, as: :json
        expect {
          post endpoint, headers: auth_headers, as: :json
        }.not_to change(Pwb::SppListing, :count)
      end

      it 'updates published_at on re-publish' do
        post endpoint, headers: auth_headers, as: :json
        first_published_at = Pwb::SppListing.last.published_at

        travel_to 1.hour.from_now do
          post endpoint, headers: auth_headers, as: :json
        end

        expect(Pwb::SppListing.last.published_at).to be > first_published_at
      end
    end

    context 'listing type independence' do
      it 'publishing sale does not affect rental' do
        rental = create(:pwb_spp_listing, :rental, realty_asset: property, active: true, visible: true)

        post endpoint, params: { listing_type: 'sale' }, headers: auth_headers, as: :json

        rental.reload
        expect(rental).to be_active
        expect(rental).to be_visible
      end

      it 'does not affect existing SaleListing or RentalListing' do
        sale_listing = create(:pwb_sale_listing, realty_asset: property)
        initial_attrs = sale_listing.attributes.dup

        post endpoint, headers: auth_headers, as: :json

        sale_listing.reload
        expect(sale_listing.visible).to eq(initial_attrs['visible'])
      end
    end

    context 'error cases' do
      it 'returns 401 without authentication' do
        post endpoint, headers: { 'HTTP_HOST' => "#{website.subdomain}.localhost" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 404 for non-existent property' do
        bad_endpoint = "/api_manage/v1/en/properties/#{SecureRandom.uuid}/spp_publish"
        post bad_endpoint, headers: auth_headers, as: :json
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 422 when spp_url_template is not configured' do
        website.update!(client_theme_config: {})

        post endpoint, headers: auth_headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['error']).to include('spp_url_template')
      end

      it 'returns 422 for invalid listing_type' do
        post endpoint, params: { listing_type: 'auction' }, headers: auth_headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['error']).to include('listing_type')
      end
    end
  end

  # ============================================
  # Unpublish Endpoint
  # ============================================
  describe 'POST /api_manage/v1/:locale/properties/:id/spp_unpublish' do
    let(:endpoint) { "/api_manage/v1/en/properties/#{property.id}/spp_unpublish" }

    context 'with active listing' do
      let!(:listing) do
        create(:pwb_spp_listing, :published, realty_asset: property)
      end

      it 'sets visible to false and returns draft status' do
        post endpoint, headers: auth_headers, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('draft')
        expect(json['listingType']).to eq('sale')
        expect(json['liveUrl']).to be_nil

        listing.reload
        expect(listing).not_to be_visible
        expect(listing).to be_active # keeps active for easy re-publish
      end
    end

    context 'listing type independence' do
      let!(:sale_listing) { create(:pwb_spp_listing, :sale, :published, realty_asset: property) }
      let!(:rental_listing) { create(:pwb_spp_listing, :rental, realty_asset: property, active: true, visible: true) }

      it 'unpublishing sale does not affect rental' do
        post endpoint, params: { listing_type: 'sale' }, headers: auth_headers, as: :json

        rental_listing.reload
        expect(rental_listing).to be_visible
        expect(rental_listing).to be_active
      end
    end

    context 're-publish after unpublish' do
      let!(:listing) { create(:pwb_spp_listing, :published, realty_asset: property) }

      it 'restores visible to true on re-publish' do
        post endpoint, headers: auth_headers, as: :json
        expect(listing.reload).not_to be_visible

        website.update!(client_theme_config: { 'spp_url_template' => 'https://{slug}.spp.example.com/' })
        post "/api_manage/v1/en/properties/#{property.id}/spp_publish", headers: auth_headers, as: :json

        expect(listing.reload).to be_visible
      end
    end

    context 'error cases' do
      it 'returns 401 without authentication' do
        post endpoint, headers: { 'HTTP_HOST' => "#{website.subdomain}.localhost" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 422 when no active SPP listing exists' do
        post endpoint, headers: auth_headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['error']).to include('No active SPP')
      end

      it 'returns 422 for invalid listing_type' do
        post endpoint, params: { listing_type: 'auction' }, headers: auth_headers, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ============================================
  # Leads Endpoint
  # ============================================
  describe 'GET /api_manage/v1/:locale/properties/:id/spp_leads' do
    let(:endpoint) { "/api_manage/v1/en/properties/#{property.id}/spp_leads" }

    context 'with linked messages' do
      let!(:contact) { create(:pwb_contact, website: website, primary_email: 'lead@example.com', first_name: 'Jane') }
      let!(:message1) do
        create(:pwb_message,
               website: website,
               contact: contact,
               realty_asset_id: property.id,
               content: 'First enquiry',
               origin_email: 'lead@example.com',
               read: true,
               created_at: 2.days.ago)
      end
      let!(:message2) do
        create(:pwb_message,
               website: website,
               contact: contact,
               realty_asset_id: property.id,
               content: 'Second enquiry',
               origin_email: 'lead@example.com',
               read: false,
               created_at: 1.hour.ago)
      end

      it 'returns messages newest first' do
        get endpoint, headers: auth_headers, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.length).to eq(2)
        expect(json[0]['id']).to eq(message2.id)
        expect(json[1]['id']).to eq(message1.id)
      end

      it 'returns correct lead fields' do
        get endpoint, headers: auth_headers, as: :json

        json = JSON.parse(response.body)
        lead = json.find { |l| l['id'] == message2.id }
        expect(lead['name']).to be_present
        expect(lead['email']).to eq('lead@example.com')
        expect(lead['message']).to eq('Second enquiry')
        expect(lead['createdAt']).to be_present
      end

      it 'marks unread messages as isNew' do
        get endpoint, headers: auth_headers, as: :json

        json = JSON.parse(response.body)
        unread_lead = json.find { |l| l['id'] == message2.id }
        expect(unread_lead['isNew']).to be true
      end

      it 'marks recent messages as isNew even if read' do
        message1.update!(read: true, created_at: 1.hour.ago)

        get endpoint, headers: auth_headers, as: :json

        json = JSON.parse(response.body)
        recent_lead = json.find { |l| l['id'] == message1.id }
        expect(recent_lead['isNew']).to be true
      end

      it 'marks old read messages as not isNew' do
        message1.update!(read: true, created_at: 5.days.ago)

        get endpoint, headers: auth_headers, as: :json

        json = JSON.parse(response.body)
        old_lead = json.find { |l| l['id'] == message1.id }
        expect(old_lead['isNew']).to be false
      end
    end

    context 'with no linked messages' do
      it 'returns empty array' do
        get endpoint, headers: auth_headers, as: :json

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to eq([])
      end
    end

    context 'does not leak cross-property messages' do
      let!(:other_property) { create(:pwb_realty_asset, website: website) }
      let!(:other_message) do
        create(:pwb_message,
               website: website,
               realty_asset_id: other_property.id,
               content: 'Other property enquiry',
               origin_email: 'other@example.com')
      end

      it 'only returns messages for the requested property' do
        get endpoint, headers: auth_headers, as: :json

        json = JSON.parse(response.body)
        expect(json).to eq([])
      end
    end

    context 'error cases' do
      it 'returns 401 without authentication' do
        get endpoint, headers: { 'HTTP_HOST' => "#{website.subdomain}.localhost" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 404 for non-existent property' do
        bad_endpoint = "/api_manage/v1/en/properties/#{SecureRandom.uuid}/spp_leads"
        get bad_endpoint, headers: auth_headers, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ============================================
  # Tenant Isolation
  # ============================================
  describe 'tenant isolation' do
    let!(:other_website) { create(:pwb_website) }
    let!(:other_property) { create(:pwb_realty_asset, website: other_website) }

    it 'cannot access another tenant property via publish' do
      website.update!(client_theme_config: { 'spp_url_template' => 'https://{slug}.spp.example.com/' })

      post "/api_manage/v1/en/properties/#{other_property.id}/spp_publish",
           headers: auth_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot access another tenant property via leads' do
      get "/api_manage/v1/en/properties/#{other_property.id}/spp_leads",
          headers: auth_headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
