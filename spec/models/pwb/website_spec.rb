require 'rails_helper'

module Pwb
  RSpec.describe Website, type: :model do
    let(:website) { FactoryBot.create(:pwb_website) }
    # let(:website2) { FactoryBot.create(:pwb_website) }

    # Multi-tenancy tests moved to website_multi_tenancy_spec.rb

    it 'has a valid factory' do
      expect(website).to be_valid
    end

    it 'has many users' do
      expect(website).to respond_to(:users)
      # You could also use shoulda-matchers if available:
      # expect(website).to have_many(:users)
    end

    it 'gets element class' do
      element_class = website.get_element_class "page_top_strip_color"
      expect(element_class).to be_present
    end

    it 'gets style variable' do
      style_var = website.get_style_var "primary-color"
      expect(style_var).to be_present
    end

    it 'sets theme_name to default if invalid_name is provided' do
      current_theme_name = website.theme_name
      website.theme_name = "invalid_name"
      website.save!
      expect(website.theme_name).to eq(current_theme_name)
    end

    it 'sets theme_name correctly if valid_name is provided' do
      website.theme_name = "brisbane"
      website.save!
      expect(website.theme_name).to eq("brisbane")
    end

    describe 'default_locale_in_supported_locales validation' do
      it 'is valid when default locale is in supported locales' do
        website.supported_locales = ['en', 'es', 'fr']
        website.default_client_locale = 'en'
        expect(website).to be_valid
      end

      it 'is valid when default locale base matches a supported locale' do
        website.supported_locales = ['en', 'es']
        website.default_client_locale = 'en-UK'
        expect(website).to be_valid
      end

      it 'is invalid when default locale is not in supported locales' do
        website.supported_locales = ['es', 'fr']
        website.default_client_locale = 'en'
        expect(website).not_to be_valid
        expect(website.errors[:default_client_locale]).to include('must be one of the supported languages')
      end

      it 'is valid when supported locales is blank (no restriction)' do
        website.supported_locales = []
        website.default_client_locale = 'de'
        expect(website).to be_valid
      end

      it 'is valid when default locale is blank' do
        website.supported_locales = ['en', 'es']
        website.default_client_locale = nil
        expect(website).to be_valid
      end
    end
  end
end
