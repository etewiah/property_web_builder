# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1 Cross-Tenant Isolation", type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'isolation-test') }

  # Create properties for the tenant
  let!(:property) do
    asset = create(:pwb_realty_asset, website: website)
    create(:pwb_sale_listing, :visible, realty_asset: asset)
    asset
  end

  before do
    Pwb::ListedProperty.refresh(concurrently: false)
    host! 'isolation-test.example.com'
    # Stub primary_host which is called during property URL generation
    allow_any_instance_of(Pwb::Website).to receive(:primary_host).and_return(nil)
  end

  describe 'Properties Isolation' do
    it 'returns properties for current tenant' do
      get '/api_public/v1/properties', params: { sale_or_rental: 'sale' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      property_ids = json['data'].map { |p| p['id'] }

      expect(property_ids).to include(property.id)
    end

    it 'can access own property by ID' do
      get "/api_public/v1/properties/#{property.id}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(property.id)
    end

    it 'can access own property by slug' do
      get "/api_public/v1/properties/#{property.slug}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(property.id)
    end

    context 'with other tenant property' do
      let!(:other_website) { create(:pwb_website, subdomain: 'other-isolation') }
      let!(:other_property) do
        asset = create(:pwb_realty_asset, website: other_website)
        create(:pwb_sale_listing, :visible, realty_asset: asset)
        Pwb::ListedProperty.refresh(concurrently: false)
        asset
      end

      it 'cannot access property from another tenant by ID' do
        get "/api_public/v1/properties/#{other_property.id}"

        expect(response).to have_http_status(:not_found)
      end

      it 'cannot access property from another tenant by slug' do
        get "/api_public/v1/properties/#{other_property.slug}"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'Enquiries Isolation' do
    let(:enquiry_params) do
      {
        enquiry: {
          name: 'Test User',
          email: 'test@example.com',
          message: 'Test enquiry message'
        }
      }
    end

    before do
      website.agency.update!(email_for_property_contact_form: 'test@agency.com')
    end

    it 'enquiry is created for current tenant' do
      post '/api_public/v1/enquiries', params: enquiry_params

      expect(response).to have_http_status(:created)
      message = Pwb::Message.last
      expect(message.website).to eq(website)
    end

    it 'contact is created for current tenant' do
      post '/api_public/v1/enquiries', params: enquiry_params

      expect(response).to have_http_status(:created)
      contact = Pwb::Contact.last
      expect(contact.website).to eq(website)
    end
  end

  describe 'Tenant Resolution' do
    it 'resolves tenant from subdomain' do
      get '/api_public/v1/properties', params: { sale_or_rental: 'sale' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      property_ids = json['data'].map { |p| p['id'] }
      expect(property_ids).to include(property.id)
    end

    context 'via custom domain' do
      before do
        website.update!(custom_domain: 'custom-isolation.com', custom_domain_verified: true)
        host! 'custom-isolation.com'
      end

      it 'resolves tenant from custom domain' do
        get '/api_public/v1/properties', params: { sale_or_rental: 'sale' }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        property_ids = json['data'].map { |p| p['id'] }
        expect(property_ids).to include(property.id)
      end
    end
  end

  describe 'Widget Isolation' do
    let!(:widget) { create(:pwb_widget_config, website: website) }

    it 'widget returns widget website data' do
      get "/api_public/v1/widgets/#{widget.widget_key}"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      # Widget config should be returned
      expect(json['config']['widget_key']).to eq(widget.widget_key)
    end
  end

  describe 'Data Leakage Prevention' do
    let!(:other_website) { create(:pwb_website, subdomain: 'leakage-test') }
    let!(:other_property) do
      asset = create(:pwb_realty_asset, website: other_website)
      create(:pwb_sale_listing, :visible, realty_asset: asset)
      Pwb::ListedProperty.refresh(concurrently: false)
      asset
    end

    it 'cannot access another tenant property by ID' do
      get "/api_public/v1/properties/#{other_property.id}"

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot access another tenant property by slug' do
      get "/api_public/v1/properties/#{other_property.slug}"

      expect(response).to have_http_status(:not_found)
    end

    it 'listing does not include other tenant properties' do
      get '/api_public/v1/properties', params: { sale_or_rental: 'sale' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      property_ids = json['data'].map { |p| p['id'] }

      expect(property_ids).to include(property.id)
      expect(property_ids).not_to include(other_property.id)
    end
  end
end
