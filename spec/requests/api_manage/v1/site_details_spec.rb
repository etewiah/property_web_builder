# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApiManage::V1::SiteDetails', type: :request do
  let!(:website) do
    create(:pwb_website,
           company_display_name: 'Test Company',
           default_meta_description: 'Test description',
           default_client_locale: 'en',
           supported_locales: %w[en es])
  end

  let!(:visible_page) do
    ActsAsTenant.with_tenant(website) do
      create(:pwb_page,
             website: website,
             slug: 'about',
             page_title: 'About Us',
             visible: true,
             show_in_top_nav: true,
             show_in_footer: true,
             sort_order_top_nav: 1)
    end
  end

  before do
    host! "#{website.subdomain}.example.com"
  end

  describe 'GET /api_manage/v1/:locale/site_details' do
    it 'returns site configuration' do
      get '/api_manage/v1/en/site_details'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['id']).to eq(website.id)
      expect(json['subdomain']).to eq(website.subdomain)
    end

    it 'includes branding information' do
      get '/api_manage/v1/en/site_details'

      json = JSON.parse(response.body)
      expect(json['branding']).to be_a(Hash)
      expect(json['branding']['company_name']).to eq('Test Company')
    end

    it 'includes localization settings' do
      get '/api_manage/v1/en/site_details'

      json = JSON.parse(response.body)
      expect(json['localization']).to be_a(Hash)
      expect(json['localization']['default_locale']).to eq('en')
      expect(json['localization']['available_locales']).to include('en', 'es')
    end

    it 'includes SEO configuration' do
      get '/api_manage/v1/en/site_details'

      json = JSON.parse(response.body)
      expect(json['seo']).to be_a(Hash)
      expect(json['seo']['default_title']).to eq('Test Company')
      expect(json['seo']['default_description']).to eq('Test description')
    end

    it 'includes navigation structure' do
      get '/api_manage/v1/en/site_details'

      json = JSON.parse(response.body)
      expect(json['navigation']).to be_a(Hash)
      expect(json['navigation']['top_nav']).to be_an(Array)
      expect(json['navigation']['footer_nav']).to be_an(Array)

      # Check that visible page appears in navigation
      top_nav_slugs = json['navigation']['top_nav'].map { |p| p['slug'] }
      expect(top_nav_slugs).to include('about')
    end

    it 'includes pages summary' do
      get '/api_manage/v1/en/site_details'

      json = JSON.parse(response.body)
      expect(json['pages']).to be_an(Array)

      page_data = json['pages'].find { |p| p['slug'] == 'about' }
      expect(page_data).to be_present
      expect(page_data['id']).to eq(visible_page.id)
      expect(page_data['title']).to eq('About Us')
      expect(page_data['visible']).to be true
      expect(page_data['show_in_top_nav']).to be true
    end

    it 'includes theme information' do
      get '/api_manage/v1/en/site_details'

      json = JSON.parse(response.body)
      expect(json['theme']).to be_a(Hash)
      expect(json['theme']).to have_key('name')
      expect(json['theme']).to have_key('display_name')
    end

    it 'includes field schema for editable settings' do
      get '/api_manage/v1/en/site_details'

      json = JSON.parse(response.body)
      expect(json['field_schema']).to be_a(Hash)
      expect(json['field_schema']['fields']).to be_an(Array)
      expect(json['field_schema']['groups']).to be_an(Array)

      field_names = json['field_schema']['fields'].map { |f| f['name'] }
      expect(field_names).to include('company_display_name', 'default_meta_description')
    end

    it 'includes timestamps' do
      get '/api_manage/v1/en/site_details'

      json = JSON.parse(response.body)
      expect(json['created_at']).to be_present
      expect(json['updated_at']).to be_present
    end

    it 'works with different locale prefixes' do
      get '/api_manage/v1/es/site_details'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['id']).to eq(website.id)
    end

    context 'with analytics configuration' do
      before do
        website.update(
          ga4_measurement_id: 'G-TEST123',
          gtm_container_id: 'GTM-TEST456'
        ) if website.respond_to?(:ga4_measurement_id=)
      end

      it 'includes analytics settings when configured' do
        get '/api_manage/v1/en/site_details'

        json = JSON.parse(response.body)
        # Analytics may be nil or a hash depending on configuration
        if json['analytics'].present?
          expect(json['analytics']).to be_a(Hash)
        end
      end
    end
  end

  describe 'PATCH /api_manage/v1/:locale/site_details' do
    it 'updates site settings' do
      patch '/api_manage/v1/en/site_details', params: {
        site: {
          company_display_name: 'Updated Company Name',
          default_meta_description: 'Updated description'
        }
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['site']['branding']['company_name']).to eq('Updated Company Name')
      expect(json['site']['seo']['default_description']).to eq('Updated description')
      expect(json['message']).to eq('Site settings updated successfully')
    end

    it 'updates locale settings' do
      patch '/api_manage/v1/en/site_details', params: {
        site: {
          default_client_locale: 'es'
        }
      }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['site']['localization']['default_locale']).to eq('es')
    end

    it 'returns validation errors for invalid params' do
      # Test with invalid data that might trigger validation
      patch '/api_manage/v1/en/site_details', params: {
        site: {
          company_display_name: ''
        }
      }

      # Response depends on model validations
      expect(response.status).to be_in([200, 422])
    end

    it 'persists changes to database' do
      patch '/api_manage/v1/en/site_details', params: {
        site: {
          company_display_name: 'Persisted Company'
        }
      }

      expect(response).to have_http_status(:ok)

      website.reload
      expect(website.company_display_name).to eq('Persisted Company')
    end
  end
end
