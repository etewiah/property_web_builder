# == Schema Information
#
# Table name: pwb_websites
#
#  id                                  :integer          not null, primary key
#  admin_config                        :json
#  analytics_id_type                   :integer
#  company_display_name                :string
#  configuration                       :json
#  custom_domain                       :string
#  custom_domain_verification_token    :string
#  custom_domain_verified              :boolean          default(FALSE)
#  custom_domain_verified_at           :datetime
#  default_admin_locale                :string           default("en-UK")
#  default_area_unit                   :integer          default("sqmt")
#  default_client_locale               :string           default("en-UK")
#  default_currency                    :string           default("EUR")
#  default_meta_description            :text
#  default_seo_title                   :string
#  email_for_general_contact_form      :string
#  email_for_property_contact_form     :string
#  email_verification_token            :string
#  email_verification_token_expires_at :datetime
#  email_verified_at                   :datetime
#  exchange_rates                      :json
#  external_image_mode                 :boolean          default(FALSE), not null
#  favicon_url                         :string
#  flags                               :integer          default(0), not null
#  google_font_name                    :string
#  imports_config                      :json
#  main_logo_url                       :string
#  maps_api_key                        :string
#  ntfy_access_token                   :string
#  ntfy_enabled                        :boolean          default(FALSE), not null
#  ntfy_notify_inquiries               :boolean          default(TRUE), not null
#  ntfy_notify_listings                :boolean          default(TRUE), not null
#  ntfy_notify_security                :boolean          default(TRUE), not null
#  ntfy_notify_users                   :boolean          default(FALSE), not null
#  ntfy_server_url                     :string           default("https://ntfy.sh")
#  ntfy_topic_prefix                   :string
#  owner_email                         :string
#  provisioning_completed_at           :datetime
#  provisioning_error                  :text
#  provisioning_failed_at              :datetime
#  provisioning_started_at             :datetime
#  provisioning_state                  :string           default("live"), not null
#  raw_css                             :text
#  recaptcha_key                       :string
#  rent_price_options_from             :text             default(["", "250", "500", "750", "1,000", "1,500", "2,500", "5,000"]), is an Array
#  rent_price_options_till             :text             default(["", "250", "500", "750", "1,000", "1,500", "2,500", "5,000"]), is an Array
#  sale_price_options_from             :text             default(["", "25,000", "50,000", "75,000", "100,000", "150,000", "250,000", "500,000", "1,000,000", "2,000,000", "5,000,000", "10,000,000"]), is an Array
#  sale_price_options_till             :text             default(["", "25,000", "50,000", "75,000", "100,000", "150,000", "250,000", "500,000", "1,000,000", "2,000,000", "5,000,000", "10,000,000"]), is an Array
#  search_config_buy                   :json
#  search_config_landing               :json
#  search_config_rent                  :json
#  seed_pack_name                      :string
#  selected_palette                    :string
#  site_type                           :string
#  slug                                :string
#  social_media                        :json
#  style_variables_for_theme           :json
#  styles_config                       :json
#  subdomain                           :string
#  supported_currencies                :text             default([]), is an Array
#  supported_locales                   :text             default(["en-UK"]), is an Array
#  theme_name                          :string
#  whitelabel_config                   :json
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  analytics_id                        :string
#  contact_address_id                  :integer
#
# Indexes
#
#  index_pwb_websites_on_custom_domain             (custom_domain) UNIQUE WHERE ((custom_domain IS NOT NULL) AND ((custom_domain)::text <> ''::text))
#  index_pwb_websites_on_email_verification_token  (email_verification_token) UNIQUE WHERE (email_verification_token IS NOT NULL)
#  index_pwb_websites_on_provisioning_state        (provisioning_state)
#  index_pwb_websites_on_selected_palette          (selected_palette)
#  index_pwb_websites_on_site_type                 (site_type)
#  index_pwb_websites_on_slug                      (slug)
#  index_pwb_websites_on_subdomain                 (subdomain) UNIQUE
#
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

    describe '#is_multilingual' do
      it 'returns true when multiple non-blank locales exist' do
        website.supported_locales = ['en', 'es']
        expect(website.is_multilingual).to be true
      end

      it 'returns false when only one non-blank locale exists' do
        website.supported_locales = ['en']
        expect(website.is_multilingual).to be false
      end

      it 'filters out blank entries when checking' do
        website.supported_locales = ['', 'en', '']
        expect(website.is_multilingual).to be false
      end

      it 'returns false when only blank entries exist' do
        website.supported_locales = ['', '']
        expect(website.is_multilingual).to be false
      end
    end

    describe '#supported_locales_with_variants' do
      it 'returns locale and variant for each supported locale' do
        website.supported_locales = ['en-UK', 'es']
        result = website.supported_locales_with_variants

        expect(result).to contain_exactly(
          { 'locale' => 'en', 'variant' => 'uk' },
          { 'locale' => 'es', 'variant' => 'es' }
        )
      end

      it 'filters out blank entries' do
        website.supported_locales = ['', 'de', '', 'fr']
        result = website.supported_locales_with_variants

        expect(result.length).to eq(2)
        expect(result.map { |r| r['locale'] }).to eq(['de', 'fr'])
      end

      it 'returns empty array when only blank entries exist' do
        website.supported_locales = ['', '']
        expect(website.supported_locales_with_variants).to eq([])
      end
    end
  end
end
