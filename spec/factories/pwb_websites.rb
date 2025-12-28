# == Schema Information
#
# Table name: pwb_websites
#
#  id                                  :integer          not null, primary key
#  admin_config                        :json
#  analytics_id_type                   :integer
#  available_currencies                :text             default([]), is an Array
#  available_themes                    :text             is an Array
#  company_display_name                :string
#  configuration                       :json
#  custom_domain                       :string
#  custom_domain_verification_token    :string
#  custom_domain_verified              :boolean          default(FALSE)
#  custom_domain_verified_at           :datetime
#  dark_mode_setting                   :string           default("light_only"), not null
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
#  index_pwb_websites_on_dark_mode_setting         (dark_mode_setting)
#  index_pwb_websites_on_email_verification_token  (email_verification_token) UNIQUE WHERE (email_verification_token IS NOT NULL)
#  index_pwb_websites_on_provisioning_state        (provisioning_state)
#  index_pwb_websites_on_selected_palette          (selected_palette)
#  index_pwb_websites_on_site_type                 (site_type)
#  index_pwb_websites_on_slug                      (slug)
#  index_pwb_websites_on_subdomain                 (subdomain) UNIQUE
#
FactoryBot.define do
  factory :pwb_website, class: 'Pwb::Website' do
    sequence(:subdomain) { |n| "tenant#{n}" }
    # NOTE: company_display_name is DEPRECATED - use agency.display_name instead
    # Keeping nil here so agency.display_name takes priority
    company_display_name { nil }
    theme_name { 'default' }
    default_currency { 'EUR' }
    default_client_locale { 'en-UK' }
    default_area_unit { 'sqmt' }
    supported_locales { ['en-UK'] }

    # Transient attribute to control agency creation
    transient do
      skip_agency { false }
    end

    # Trait for creating a website without an agency (for testing guards)
    trait :without_agency do
      transient do
        skip_agency { true }
      end
    end

    # Trait for testing legacy company_display_name fallback
    trait :with_legacy_company_display_name do
      company_display_name { 'Legacy Website Company' }
    end

    after(:create) do |website, evaluator|
      # Create an agency for the website if not already created
      # Skip if using :without_agency trait
      next if evaluator.skip_agency

      unless website.agency.present?
        agency = Pwb::Agency.create!(
          company_name: 'Test Company',
          # display_name is the primary source for the company name shown on the public website
          display_name: 'Test Company',
          website: website
        )
        website.update(agency: agency)
      end
    end
  end
end
