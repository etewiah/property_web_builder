# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Locale URL handling', type: :request do
  let!(:website) { create(:pwb_website, subdomain: 'test-locale') }

  before do
    # Set up the current website
    allow_any_instance_of(ActionController::Base).to receive(:current_website).and_return(website)
    host! "#{website.subdomain}.example.com"
  end

  describe 'home page with Spanish locale' do
    it 'renders the home page at /es' do
      get '/es'
      expect(response).to have_http_status(:success)
    end

    it 'sets the locale correctly' do
      get '/es'
      expect(I18n.locale).to eq(:es)
    end
  end

  describe 'buy page routing' do
    it 'renders at /es/buy for Spanish' do
      get '/es/buy'
      expect(response).to have_http_status(:success)
    end

    it 'renders at /buy without locale' do
      get '/buy'
      expect(response).to have_http_status(:success)
    end
  end

  describe 'route helpers include locale when set' do
    it 'buy_path includes locale when locale is set' do
      I18n.with_locale(:es) do
        expect(Rails.application.routes.url_helpers.buy_path(locale: :es)).to eq('/es/buy')
      end
    end

    it 'buy_path works without locale' do
      expect(Rails.application.routes.url_helpers.buy_path).to eq('/buy')
    end

    it 'home_path includes locale when specified' do
      expect(Rails.application.routes.url_helpers.home_path(locale: :fr)).to eq('/fr')
    end

    it 'contact_us_path includes locale when specified' do
      expect(Rails.application.routes.url_helpers.contact_us_path(locale: :de)).to eq('/de/contact-us')
    end
  end
end
