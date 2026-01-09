# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_websites
# Database name: primary
#
#  id                                  :integer          not null, primary key
#  admin_config                        :json
#  analytics_id_type                   :integer
#  available_currencies                :text             default([]), is an Array
#  available_themes                    :text             is an Array
#  company_display_name                :string
#  compiled_palette_css                :text
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
#  demo_last_reset_at                  :datetime
#  demo_mode                           :boolean          default(FALSE), not null
#  demo_reset_interval                 :interval         default(24 hours)
#  demo_seed_pack                      :string
#  email_for_general_contact_form      :string
#  email_for_property_contact_form     :string
#  email_verification_token            :string
#  email_verification_token_expires_at :datetime
#  email_verified_at                   :datetime
#  exchange_rates                      :json
#  external_feed_config                :json
#  external_feed_enabled               :boolean          default(FALSE), not null
#  external_feed_provider              :string
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
#  palette_compiled_at                 :datetime
#  palette_mode                        :string           default("dynamic"), not null
#  provisioning_completed_at           :datetime
#  provisioning_error                  :text
#  provisioning_failed_at              :datetime
#  provisioning_started_at             :datetime
#  provisioning_state                  :string           default("live"), not null
#  raw_css                             :text
#  realty_assets_count                 :integer          default(0), not null
#  recaptcha_key                       :string
#  rent_price_options_from             :text             default(["", "250", "500", "750", "1,000", "1,500", "2,500", "5,000"]), is an Array
#  rent_price_options_till             :text             default(["", "250", "500", "750", "1,000", "1,500", "2,500", "5,000"]), is an Array
#  sale_price_options_from             :text             default(["", "25,000", "50,000", "75,000", "100,000", "150,000", "250,000", "500,000", "1,000,000", "2,000,000", "5,000,000", "10,000,000"]), is an Array
#  sale_price_options_till             :text             default(["", "25,000", "50,000", "75,000", "100,000", "150,000", "250,000", "500,000", "1,000,000", "2,000,000", "5,000,000", "10,000,000"]), is an Array
#  search_config                       :jsonb            not null
#  search_config_buy                   :json
#  search_config_landing               :json
#  search_config_rent                  :json
#  seed_pack_name                      :string
#  selected_palette                    :string
#  shard_name                          :string           default("default")
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
#  index_pwb_websites_on_demo_mode_and_shard_name  (demo_mode,shard_name)
#  index_pwb_websites_on_email_verification_token  (email_verification_token) UNIQUE WHERE (email_verification_token IS NOT NULL)
#  index_pwb_websites_on_external_feed_enabled     (external_feed_enabled)
#  index_pwb_websites_on_external_feed_provider    (external_feed_provider)
#  index_pwb_websites_on_palette_mode              (palette_mode)
#  index_pwb_websites_on_provisioning_state        (provisioning_state)
#  index_pwb_websites_on_realty_assets_count       (realty_assets_count)
#  index_pwb_websites_on_search_config             (search_config) USING gin
#  index_pwb_websites_on_selected_palette          (selected_palette)
#  index_pwb_websites_on_site_type                 (site_type)
#  index_pwb_websites_on_slug                      (slug)
#  index_pwb_websites_on_subdomain                 (subdomain) UNIQUE
#
require 'rails_helper'

module Pwb
  RSpec.describe Website, type: :model do
    # Set up tenant settings to allow all themes used in tests
    before(:all) do
      Pwb::TenantSettings.delete_all
      Pwb::TenantSettings.create!(
        singleton_key: "default",
        default_available_themes: %w[default brisbane bologna barcelona biarritz]
      )
    end

    after(:all) do
      Pwb::TenantSettings.delete_all
    end

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
        website.supported_locales = %w[en es fr]
        website.default_client_locale = 'en'
        expect(website).to be_valid
      end

      it 'is valid when default locale base matches a supported locale' do
        website.supported_locales = %w[en es]
        website.default_client_locale = 'en-UK'
        expect(website).to be_valid
      end

      it 'is invalid when default locale is not in supported locales' do
        website.supported_locales = %w[es fr]
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
        website.supported_locales = %w[en es]
        website.default_client_locale = nil
        expect(website).to be_valid
      end
    end

    describe '#is_multilingual' do
      it 'returns true when multiple non-blank locales exist' do
        website.supported_locales = %w[en es]
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
        website.supported_locales = %w[en-UK es]
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
        expect(result.pluck('locale')).to eq(%w[de fr])
      end

      it 'returns empty array when only blank entries exist' do
        website.supported_locales = ['', '']
        expect(website.supported_locales_with_variants).to eq([])
      end
    end

    # ============================================
    # Palette Integration Tests
    # ============================================

    describe '#selected_palette' do
      it 'can be set and persisted' do
        website.selected_palette = 'ocean_blue'
        website.save!
        website.reload

        expect(website.selected_palette).to eq('ocean_blue')
      end

      it 'defaults to theme default palette when theme has palettes' do
        # Website factory sets theme_name to 'default', which triggers ensure_palette_selected
        # to auto-set the theme's default palette
        new_website = FactoryBot.create(:pwb_website)
        expect(new_website.selected_palette).to eq('classic_red')
      end
    end

    describe '#current_theme' do
      it 'returns Theme instance for theme_name' do
        website.theme_name = 'brisbane'
        website.save!

        expect(website.current_theme).to be_a(Pwb::Theme)
        expect(website.current_theme.name).to eq('brisbane')
      end

      it 'returns nil for invalid theme' do
        website.update_column(:theme_name, 'nonexistent')
        # Get a fresh instance since update_column bypasses callbacks and
        # reload doesn't clear memoized @current_theme
        fresh_website = Pwb::Website.find(website.id)

        expect(fresh_website.current_theme).to be_nil
      end
    end

    describe '#effective_palette_id' do
      context 'with selected palette' do
        before do
          website.theme_name = 'default'
          website.selected_palette = 'ocean_blue'
          website.save!
        end

        it 'returns selected palette when valid' do
          expect(website.effective_palette_id).to eq('ocean_blue')
        end
      end

      context 'without selected palette' do
        before do
          website.theme_name = 'default'
          website.selected_palette = nil
          website.save!
        end

        it 'returns theme default palette' do
          expect(website.effective_palette_id).to eq('classic_red')
        end
      end

      context 'with invalid selected palette' do
        before do
          website.theme_name = 'default'
          website.update_column(:selected_palette, 'nonexistent')
        end

        it 'falls back to theme default' do
          expect(website.effective_palette_id).to eq('classic_red')
        end
      end
    end

    describe '#apply_palette!' do
      before do
        website.theme_name = 'default'
        website.save!
      end

      it 'sets selected_palette for valid palette' do
        result = website.apply_palette!('forest_green')

        expect(result).to be true
        expect(website.reload.selected_palette).to eq('forest_green')
      end

      it 'returns false for invalid palette' do
        result = website.apply_palette!('nonexistent')

        expect(result).to be false
      end

      it 'does not change palette for invalid input' do
        website.update!(selected_palette: 'ocean_blue')
        website.apply_palette!('nonexistent')

        expect(website.reload.selected_palette).to eq('ocean_blue')
      end
    end

    describe '#available_palettes' do
      it 'returns palettes for current theme' do
        website.theme_name = 'brisbane'
        website.save!

        palettes = website.available_palettes

        expect(palettes).to be_a(Hash)
        expect(palettes.keys).to include('gold_navy', 'emerald_luxury')
      end

      it 'returns empty hash when no theme' do
        website.update_column(:theme_name, 'nonexistent')
        # Get a fresh instance since update_column bypasses callbacks and
        # reload doesn't clear memoized @current_theme
        fresh_website = Pwb::Website.find(website.id)

        expect(fresh_website.available_palettes).to eq({})
      end
    end

    describe '#palette_options_for_select' do
      before do
        website.theme_name = 'default'
        website.save!
      end

      it 'returns options suitable for form select' do
        options = website.palette_options_for_select

        expect(options).to be_an(Array)
        expect(options.first).to be_an(Array)
      end

      it 'includes all theme palettes' do
        options = website.palette_options_for_select
        ids = options.map(&:last)

        expect(ids).to include('classic_red', 'ocean_blue', 'forest_green', 'sunset_orange')
      end
    end

    describe '#style_variables with palette' do
      context 'with selected palette' do
        before do
          website.theme_name = 'brisbane'
          website.selected_palette = 'emerald_luxury'
          website.save!
        end

        it 'includes palette colors in style_variables' do
          vars = website.style_variables

          expect(vars['primary_color']).to eq('#2d6a4f')
          expect(vars['action_color']).to eq('#2d6a4f')
        end

        it 'palette colors override base variables' do
          # Set a different primary_color in base vars
          website.style_variables = { 'primary_color' => '#ff0000' }
          website.save!

          vars = website.style_variables

          # Palette should override
          expect(vars['primary_color']).to eq('#2d6a4f')
        end
      end

      context 'without selected palette' do
        before do
          website.theme_name = 'default'
          website.selected_palette = nil
          website.save!
        end

        it 'returns base style variables' do
          vars = website.style_variables

          expect(vars).to be_a(Hash)
          expect(vars).to have_key('primary_color')
        end
      end

      context 'switching palettes' do
        before do
          website.theme_name = 'default'
          website.save!
        end

        it 'reflects new palette colors after change' do
          website.selected_palette = 'classic_red'
          vars_red = website.style_variables.dup

          website.selected_palette = 'ocean_blue'
          # Clear memoized current_theme
          website.instance_variable_set(:@current_theme, nil)
          vars_blue = website.style_variables

          expect(vars_red['primary_color']).to eq('#e91b23')
          expect(vars_blue['primary_color']).to eq('#3498db')
        end
      end
    end

    describe 'theme and palette interaction' do
      it 'switching theme clears invalid palette' do
        website.theme_name = 'brisbane'
        website.selected_palette = 'gold_navy'
        website.save!

        # Change to default theme
        website.theme_name = 'default'
        website.save!

        # gold_navy is not valid for default theme
        expect(website.current_theme.valid_palette?('gold_navy')).to be false
        # effective_palette_id should fall back to default theme's default
        expect(website.effective_palette_id).to eq('classic_red')
      end
    end

    # ============================================
    # Theme Availability Tests (WebsiteThemeable)
    # ============================================

    describe 'WebsiteThemeable concern' do
      before do
        # Set up tenant settings with default themes
        Pwb::TenantSettings.delete_all
        Pwb::TenantSettings.create!(
          singleton_key: 'default',
          default_available_themes: %w[default brisbane bologna]
        )
      end

      describe '#accessible_theme_names' do
        it 'returns tenant default themes when no website-specific themes set' do
          website.available_themes = nil
          expect(website.accessible_theme_names).to contain_exactly('default', 'brisbane', 'bologna')
        end

        it 'returns website-specific themes when set' do
          website.available_themes = %w[default brisbane]
          expect(website.accessible_theme_names).to contain_exactly('default', 'brisbane')
        end

        it 'always includes default theme' do
          website.available_themes = %w[brisbane bologna]
          expect(website.accessible_theme_names).to include('default')
        end
      end

      describe '#accessible_themes' do
        it 'returns Theme objects for accessible themes' do
          website.available_themes = nil
          themes = website.accessible_themes

          expect(themes).to all(be_a(Pwb::Theme))
          expect(themes.map(&:name)).to contain_exactly('default', 'brisbane', 'bologna')
        end

        it 'only returns enabled themes' do
          website.available_themes = %w[default brisbane nonexistent]
          themes = website.accessible_themes

          expect(themes.map(&:name)).not_to include('nonexistent')
        end
      end

      describe '#theme_accessible?' do
        before do
          website.available_themes = %w[default brisbane]
        end

        it 'returns true for accessible themes' do
          expect(website.theme_accessible?('default')).to be true
          expect(website.theme_accessible?('brisbane')).to be true
        end

        it 'returns false for inaccessible themes' do
          expect(website.theme_accessible?('bologna')).to be false
          expect(website.theme_accessible?('barcelona')).to be false
        end

        it 'always returns true for default theme' do
          website.available_themes = %w[brisbane]
          expect(website.theme_accessible?('default')).to be true
        end

        it 'handles symbol input' do
          expect(website.theme_accessible?(:brisbane)).to be true
        end
      end

      describe '#custom_theme_availability?' do
        it 'returns true when website has custom themes' do
          website.available_themes = %w[default brisbane]
          expect(website.custom_theme_availability?).to be true
        end

        it 'returns false when using tenant defaults' do
          website.available_themes = nil
          expect(website.custom_theme_availability?).to be false
        end

        it 'returns false when available_themes is empty array' do
          website.available_themes = []
          expect(website.custom_theme_availability?).to be false
        end
      end

      describe '#update_available_themes' do
        it 'updates available themes' do
          website.update_available_themes(%w[default brisbane])
          expect(website.reload.available_themes).to eq(%w[default brisbane])
        end

        it 'rejects blank values' do
          website.update_available_themes(['default', '', 'brisbane', nil])
          expect(website.reload.available_themes).to eq(%w[default brisbane])
        end
      end

      describe '#reset_to_default_themes' do
        it 'clears website-specific themes' do
          website.available_themes = %w[default brisbane]
          website.save!

          website.reset_to_default_themes

          expect(website.reload.available_themes).to be_nil
        end
      end

      describe 'theme validation' do
        before do
          website.available_themes = %w[default brisbane]
          website.save!
        end

        it 'allows setting accessible themes' do
          website.theme_name = 'brisbane'
          expect(website).to be_valid
        end

        it 'prevents setting inaccessible themes' do
          website.theme_name = 'bologna'
          expect(website).not_to be_valid
          expect(website.errors[:theme_name]).to include('is not available for this website')
        end

        it 'always allows default theme' do
          website.theme_name = 'default'
          expect(website).to be_valid
        end
      end
    end

    # ============================================
    # Social Media Link Tests (WebsiteSocialLinkable)
    # ============================================

    describe 'WebsiteSocialLinkable concern' do
      describe '#social_media_facebook' do
        it 'returns nil when no facebook link exists' do
          expect(website.social_media_facebook).to be_nil
        end

        it 'returns the URL when facebook link exists' do
          website.links.create!(
            slug: 'social_media_facebook',
            link_url: 'https://facebook.com/testpage',
            placement: :social_media
          )
          expect(website.social_media_facebook).to eq('https://facebook.com/testpage')
        end
      end

      describe '#social_media_instagram' do
        it 'returns nil when no instagram link exists' do
          expect(website.social_media_instagram).to be_nil
        end

        it 'returns the URL when instagram link exists' do
          website.links.create!(
            slug: 'social_media_instagram',
            link_url: 'https://instagram.com/testhandle',
            placement: :social_media
          )
          expect(website.social_media_instagram).to eq('https://instagram.com/testhandle')
        end
      end

      describe '#social_media_whatsapp' do
        it 'returns nil when no whatsapp link exists' do
          expect(website.social_media_whatsapp).to be_nil
        end

        it 'returns the URL when whatsapp link exists' do
          website.links.create!(
            slug: 'social_media_whatsapp',
            link_url: 'https://wa.me/1234567890',
            placement: :social_media
          )
          expect(website.social_media_whatsapp).to eq('https://wa.me/1234567890')
        end
      end

      describe '#social_media_links_for_admin' do
        it 'returns all 7 platforms' do
          result = website.social_media_links_for_admin

          expect(result.length).to eq(7)
          expect(result.pluck(:platform)).to contain_exactly(
            'facebook', 'instagram', 'linkedin', 'youtube', 'twitter', 'whatsapp', 'pinterest'
          )
        end

        it 'includes existing link URLs' do
          website.links.create!(
            slug: 'social_media_facebook',
            link_url: 'https://facebook.com/test',
            placement: :social_media
          )

          result = website.social_media_links_for_admin
          facebook_link = result.find { |r| r[:platform] == 'facebook' }

          expect(facebook_link[:url]).to eq('https://facebook.com/test')
        end

        it 'returns nil URL for platforms without links' do
          result = website.social_media_links_for_admin
          twitter_link = result.find { |r| r[:platform] == 'twitter' }

          expect(twitter_link[:url]).to be_nil
        end
      end

      describe '#update_social_media_link' do
        it 'creates a new link when none exists' do
          expect do
            website.update_social_media_link('facebook', 'https://facebook.com/newpage')
          end.to change { website.links.count }.by(1)

          link = website.links.find_by(slug: 'social_media_facebook')
          expect(link.link_url).to eq('https://facebook.com/newpage')
          expect(link.placement).to eq('social_media')
          expect(link.visible).to be true
        end

        it 'updates an existing link' do
          website.links.create!(
            slug: 'social_media_facebook',
            link_url: 'https://facebook.com/oldpage',
            placement: :social_media
          )

          website.update_social_media_link('facebook', 'https://facebook.com/newpage')

          link = website.links.find_by(slug: 'social_media_facebook')
          expect(link.link_url).to eq('https://facebook.com/newpage')
        end

        it 'sets visible to false when URL is blank' do
          website.update_social_media_link('facebook', '')

          link = website.links.find_by(slug: 'social_media_facebook')
          expect(link.visible).to be false
        end

        it 'sets icon_class correctly' do
          website.update_social_media_link('instagram', 'https://instagram.com/test')

          link = website.links.find_by(slug: 'social_media_instagram')
          expect(link.icon_class).to eq('fa fa-instagram')
        end
      end
    end
  end
end
