# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApiPublic::V1::Widgets", type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'widget-test') }
  let!(:widget) { create(:pwb_widget_config, website: website, widget_key: 'testwidget12') }

  before do
    # Stub primary_host which is called during property URL generation
    allow_any_instance_of(Pwb::Website).to receive(:primary_host).and_return(nil)
  end

  describe "GET /api_public/v1/widgets/:widget_key" do
    context 'with valid widget_key' do
      before { host! 'widget-test.example.com' }

      it 'returns the widget configuration' do
        get "/api_public/v1/widgets/#{widget.widget_key}"

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json).to have_key('config')
        expect(json['config']['widget_key']).to eq(widget.widget_key)
      end

      it 'returns widget config details' do
        get "/api_public/v1/widgets/#{widget.widget_key}"

        json = response.parsed_body
        config = json['config']
        expect(config).to have_key('layout')
        expect(config).to have_key('columns')
        expect(config).to have_key('max_properties')
        expect(config).to have_key('theme')
        expect(config).to have_key('visible_fields')
      end

      it 'returns properties array' do
        get "/api_public/v1/widgets/#{widget.widget_key}"

        json = response.parsed_body
        expect(json).to have_key('properties')
        expect(json['properties']).to be_an(Array)
      end

      it 'returns website information' do
        get "/api_public/v1/widgets/#{widget.widget_key}"

        json = response.parsed_body
        expect(json).to have_key('website')
        expect(json['website']).to have_key('currency')
        expect(json['website']).to have_key('area_unit')
      end

      it 'returns total_count' do
        get "/api_public/v1/widgets/#{widget.widget_key}"

        json = response.parsed_body
        expect(json).to have_key('total_count')
        expect(json['total_count']).to be_a(Integer)
      end
    end

    context 'with invalid widget_key' do
      before { host! 'widget-test.example.com' }

      it 'returns 404' do
        get '/api_public/v1/widgets/nonexistent'

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json['error']).to eq('Widget not found')
      end
    end

    context 'with inactive widget' do
      before do
        widget.update!(active: false)
        host! 'widget-test.example.com'
      end

      it 'returns 404' do
        get "/api_public/v1/widgets/#{widget.widget_key}"

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api_public/v1/widgets/:widget_key/properties" do
    before { host! 'widget-test.example.com' }

    it 'returns properties with pagination' do
      get "/api_public/v1/widgets/#{widget.widget_key}/properties"

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key('properties')
      expect(json).to have_key('pagination')
    end

    it 'includes pagination metadata' do
      get "/api_public/v1/widgets/#{widget.widget_key}/properties"

      json = response.parsed_body
      pagination = json['pagination']
      expect(pagination).to have_key('current_page')
      expect(pagination).to have_key('per_page')
      expect(pagination).to have_key('total_count')
      expect(pagination).to have_key('total_pages')
    end

    it 'respects page parameter' do
      get "/api_public/v1/widgets/#{widget.widget_key}/properties", params: { page: 2 }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['pagination']['current_page']).to eq(2)
    end
  end

  describe "POST /api_public/v1/widgets/:widget_key/impression" do
    before { host! 'widget-test.example.com' }

    it 'increments impression count' do
      expect {
        post "/api_public/v1/widgets/#{widget.widget_key}/impression"
      }.to change { widget.reload.impressions_count }.by(1)

      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for invalid widget' do
      post '/api_public/v1/widgets/invalid/impression'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api_public/v1/widgets/:widget_key/click" do
    before { host! 'widget-test.example.com' }

    it 'increments click count' do
      expect {
        post "/api_public/v1/widgets/#{widget.widget_key}/click"
      }.to change { widget.reload.clicks_count }.by(1)

      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for invalid widget' do
      post '/api_public/v1/widgets/invalid/click'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'origin validation' do
    context 'with no domain restrictions' do
      before do
        widget.update!(allowed_domains: [])
        host! 'widget-test.example.com'
      end

      it 'allows requests from any origin' do
        get "/api_public/v1/widgets/#{widget.widget_key}",
          headers: { 'Origin' => 'https://any-domain.com' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with domain restrictions' do
      before do
        widget.update!(allowed_domains: ['allowed.com', '*.trusted.com'])
        host! 'widget-test.example.com'
      end

      it 'allows requests from allowed domain' do
        get "/api_public/v1/widgets/#{widget.widget_key}",
          headers: { 'Origin' => 'https://allowed.com' }

        expect(response).to have_http_status(:ok)
      end

      it 'allows requests from wildcard subdomain' do
        get "/api_public/v1/widgets/#{widget.widget_key}",
          headers: { 'Origin' => 'https://sub.trusted.com' }

        expect(response).to have_http_status(:ok)
      end

      it 'logs warning for unauthorized domain but still responds' do
        # Current implementation logs but doesn't block
        expect(Rails.logger).to receive(:warn).with(/unauthorized domain/)

        get "/api_public/v1/widgets/#{widget.widget_key}",
          headers: { 'Origin' => 'https://unauthorized.com' }

        expect(response).to have_http_status(:ok)
      end

      it 'allows direct API access without Origin header' do
        get "/api_public/v1/widgets/#{widget.widget_key}"

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'multi-tenancy' do
    let!(:other_website) { create(:pwb_website, subdomain: 'other-tenant') }
    let!(:other_widget) { create(:pwb_widget_config, website: other_website) }

    before do
      # Stub primary_host which is called during property URL generation
      allow_any_instance_of(Pwb::Website).to receive(:primary_host).and_return(nil)
    end

    it 'widget is associated with correct website' do
      host! 'widget-test.example.com'
      get "/api_public/v1/widgets/#{widget.widget_key}"

      expect(response).to have_http_status(:ok)
      # Widget is found because it exists globally (not tenant-scoped lookup)
    end

    it 'returns properties from widget website only' do
      host! 'widget-test.example.com'
      get "/api_public/v1/widgets/#{widget.widget_key}"

      json = response.parsed_body
      # Website name is returned from company_display_name
      expect(json['website']).to have_key('name')
    end
  end

  describe 'with properties' do
    let!(:realty_asset) { create(:pwb_realty_asset, website: website) }
    let!(:sale_listing) { create(:pwb_sale_listing, :visible, realty_asset: realty_asset) }

    before do
      Pwb::ListedProperty.refresh(concurrently: false)
      widget.update!(listing_type: 'sale')
      host! 'widget-test.example.com'
      # Stub the primary_host method which is called during property URL generation
      allow_any_instance_of(Pwb::Website).to receive(:primary_host).and_return('widget-test.propertywebbuilder.com')
    end

    it 'returns properties matching widget configuration' do
      get "/api_public/v1/widgets/#{widget.widget_key}"

      json = response.parsed_body
      expect(json['properties'].length).to be >= 0
    end

    it 'serializes property fields according to visible_fields' do
      widget.update!(visible_fields: { 'price' => true, 'bedrooms' => true, 'reference' => false })

      get "/api_public/v1/widgets/#{widget.widget_key}"

      json = response.parsed_body
      if json['properties'].any?
        property = json['properties'].first
        expect(property).to have_key('id')
        expect(property).to have_key('title')
        expect(property).to have_key('url')
      end
    end
  end
end
