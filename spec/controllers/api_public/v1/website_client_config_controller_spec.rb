# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiPublic::V1::WebsiteClientConfigController, type: :controller do
  # Set up tenant settings
  before(:all) do
    Pwb::TenantSettings.find_or_create_by!(singleton_key: 'default') do |ts|
      ts.default_available_themes = %w[default brisbane]
    end
  end

  describe 'GET #show' do
    context 'with rails-rendered website' do
      let!(:website) { create(:pwb_website, :rails_rendering) }

      before do
        allow(controller).to receive(:current_website).and_return(website)
        controller.instance_variable_set(:@current_website, website)
      end

      it 'returns ok with error message' do
        get :show

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json.dig('error', 'message')).to eq('Client rendering not enabled for this website')
        expect(json.dig('error', 'rendering_mode')).to eq('rails')
      end
    end

    context 'with client-rendered website' do
      let!(:client_theme) do
        create(:pwb_client_theme,
               name: 'test_theme',
               friendly_name: 'Test Theme',
               default_config: { 'primary_color' => '#FF0000' })
      end
      let!(:website) do
        create(:pwb_website,
               rendering_mode: 'client',
               client_theme_name: 'test_theme',
               client_theme_config: { 'primary_color' => '#00FF00' })
      end

      before do
        allow(controller).to receive(:current_website).and_return(website)
        controller.instance_variable_set(:@current_website, website)
      end

      it 'returns success' do
        get :show

        expect(response).to have_http_status(:ok)
      end

      it 'returns rendering mode' do
        get :show

        json = JSON.parse(response.body)
        expect(json['data']['rendering_mode']).to eq('client')
      end

      it 'returns theme data' do
        get :show

        json = JSON.parse(response.body)
        theme = json['data']['theme']

        expect(theme['name']).to eq('test_theme')
        expect(theme['friendly_name']).to eq('Test Theme')
      end

      it 'returns merged config (overrides applied)' do
        get :show

        json = JSON.parse(response.body)
        config = json['data']['config']

        # Website override should take precedence
        expect(config['primary_color']).to eq('#00FF00')
      end

      it 'returns CSS variables' do
        get :show

        json = JSON.parse(response.body)
        css = json['data']['css_variables']

        expect(css).to include(':root')
        expect(css).to include('--primary-color')
      end

      it 'returns website data' do
        get :show

        json = JSON.parse(response.body)
        website_data = json['data']['website']

        expect(website_data['id']).to eq(website.id)
        expect(website_data['subdomain']).to eq(website.subdomain)
      end
    end

    context 'with no current website' do
      before do
        allow(controller).to receive(:current_website).and_return(nil)
        controller.instance_variable_set(:@current_website, nil)
      end

      it 'returns ok with error payload' do
        get :show

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.dig('error', 'rendering_mode')).to eq('unknown')
      end
    end
  end
end
