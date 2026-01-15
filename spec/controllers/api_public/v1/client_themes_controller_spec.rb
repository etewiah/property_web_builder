# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiPublic::V1::ClientThemesController, type: :controller do
  # Set up tenant settings
  before(:all) do
    Pwb::TenantSettings.find_or_create_by!(singleton_key: 'default') do |ts|
      ts.default_available_themes = %w[default brisbane]
    end
  end

  let!(:website) { create(:pwb_website) }

  before do
    allow(controller).to receive(:current_website).and_return(website)
    controller.instance_variable_set(:@current_website, website)
  end

  describe 'GET #index' do
    let!(:theme1) { create(:pwb_client_theme, name: 'alpha', friendly_name: 'Alpha Theme') }
    let!(:theme2) { create(:pwb_client_theme, name: 'beta', friendly_name: 'Beta Theme') }
    let!(:disabled) { create(:pwb_client_theme, :disabled, name: 'disabled') }

    it 'returns all enabled themes' do
      get :index

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['meta']['total']).to eq(2)
      expect(json['data'].length).to eq(2)
    end

    it 'orders themes by friendly_name' do
      get :index

      json = JSON.parse(response.body)
      names = json['data'].map { |t| t['name'] }

      expect(names).to eq(%w[alpha beta])
    end

    it 'does not include disabled themes' do
      get :index

      json = JSON.parse(response.body)
      names = json['data'].map { |t| t['name'] }

      expect(names).not_to include('disabled')
    end

    it 'includes theme configuration data' do
      get :index

      json = JSON.parse(response.body)
      theme_data = json['data'].first

      expect(theme_data).to have_key('default_config')
      expect(theme_data).to have_key('color_schema')
    end
  end

  describe 'GET #show' do
    let!(:theme) { create(:pwb_client_theme, :amsterdam) }

    context 'when theme exists' do
      it 'returns the theme' do
        get :show, params: { name: 'amsterdam' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['data']['name']).to eq('amsterdam')
        expect(json['data']['friendly_name']).to eq('Amsterdam Modern')
      end
    end

    context 'when theme does not exist' do
      it 'returns 404' do
        get :show, params: { name: 'nonexistent' }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Theme not found')
      end
    end

    context 'when theme is disabled' do
      let!(:disabled) { create(:pwb_client_theme, :disabled, name: 'disabled_theme') }

      it 'returns 404' do
        get :show, params: { name: 'disabled_theme' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
