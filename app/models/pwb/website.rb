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
#  client_theme_config                 :jsonb
#  client_theme_name                   :string
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
#  rendering_mode                      :string           default("rails"), not null
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
#  index_pwb_websites_on_rendering_mode            (rendering_mode)
#  index_pwb_websites_on_search_config             (search_config) USING gin
#  index_pwb_websites_on_selected_palette          (selected_palette)
#  index_pwb_websites_on_site_type                 (site_type)
#  index_pwb_websites_on_slug                      (slug)
#  index_pwb_websites_on_subdomain                 (subdomain) UNIQUE
#
module Pwb
  class Website < ApplicationRecord
    # ===================
    # Concerns
    # ===================
    include Pwb::WebsiteProvisionable
    include Pwb::WebsiteDomainConfigurable
    include Pwb::WebsiteStyleable
    include Pwb::WebsiteSubscribable
    include Pwb::WebsiteSocialLinkable
    include Pwb::WebsiteLocalizable
    include Pwb::WebsiteThemeable
    include Pwb::WebsiteRenderingMode
    include Pwb::DemoWebsite
    include FlagShihTzu

    # Virtual attributes for form handling (avoid conflict with AASM events)
    attr_accessor :seed_data, :skip_property_seeding

    # ===================
    # Associations
    # ===================
    extend ActiveHash::Associations::ActiveRecordExtensions
    belongs_to_active_hash :theme, optional: true, foreign_key: "theme_name",
                           class_name: "Pwb::Theme", shortcuts: [:friendly_name], primary_key: "name"

    has_many :page_contents, class_name: 'Pwb::PageContent'
    has_many :contents, through: :page_contents, class_name: 'Pwb::Content'
    has_many :ordered_visible_page_contents, -> { ordered_visible.includes(:content) }, class_name: 'Pwb::PageContent'

    # Listed properties from the materialized view (read-only, for display)
    has_many :listed_properties, class_name: 'Pwb::ListedProperty', foreign_key: 'website_id'
    # Legacy Prop model - kept for backwards compatibility
    has_many :props, class_name: 'Pwb::Prop', foreign_key: 'website_id'

    has_many :realty_assets, class_name: 'Pwb::RealtyAsset', foreign_key: 'website_id'
    has_many :sale_listings, through: :realty_assets, class_name: 'Pwb::SaleListing'
    has_many :rental_listings, through: :realty_assets, class_name: 'Pwb::RentalListing'

    has_many :pages, class_name: 'Pwb::Page'
    has_many :links, class_name: 'Pwb::Link'
    has_many :users
    has_many :auth_audit_logs, class_name: 'Pwb::AuthAuditLog', dependent: :destroy
    has_many :contacts, class_name: 'Pwb::Contact'
    has_many :messages, class_name: 'Pwb::Message'
    has_many :support_tickets, class_name: 'Pwb::SupportTicket', dependent: :destroy
    has_many :ticket_messages, class_name: 'Pwb::TicketMessage', dependent: :destroy
    has_many :website_photos
    has_many :field_keys, class_name: 'Pwb::FieldKey', foreign_key: :pwb_website_id
    has_many :email_templates, class_name: 'Pwb::EmailTemplate', dependent: :destroy
    has_many :shard_audit_logs, class_name: 'Pwb::ShardAuditLog', dependent: :destroy
    has_many :testimonials, class_name: 'Pwb::Testimonial', dependent: :destroy

    # Media Library
    has_many :media, class_name: 'Pwb::Media', dependent: :destroy
    has_many :media_folders, class_name: 'Pwb::MediaFolder', dependent: :destroy

    # Embeddable Widgets
    has_many :widget_configs, class_name: 'Pwb::WidgetConfig', dependent: :destroy

    # AI Content Generation
    has_many :ai_generation_requests, class_name: 'Pwb::AiGenerationRequest', dependent: :destroy
    has_many :ai_writing_rules, class_name: 'Pwb::AiWritingRule', dependent: :destroy

    # External Service Integrations
    has_many :integrations, class_name: 'Pwb::WebsiteIntegration', dependent: :destroy

    # Multi-website support via memberships
    has_many :user_memberships, dependent: :destroy
    has_many :members, through: :user_memberships, source: :user

    has_one :agency, class_name: 'Pwb::Agency'
    has_one :allocated_subdomain, class_name: 'Pwb::Subdomain', foreign_key: 'website_id'
    has_one :subscription, class_name: 'Pwb::Subscription', dependent: :destroy

    # ===================
    # Constants & Enums
    # ===================
    SITE_TYPES = %w[residential commercial vacation_rental].freeze

    enum :default_area_unit, { sqmt: 0, sqft: 1 }

    has_flags 1 => :landing_hide_for_rent,
              2 => :landing_hide_for_sale,
              3 => :landing_hide_search_bar

    # ===================
    # Validations
    # ===================
    validates :site_type, inclusion: { in: SITE_TYPES }, allow_blank: true

    # ===================
    # Instance Methods
    # ===================

    def admins
      members.where(pwb_user_memberships: { role: ['owner', 'admin'], active: true })
    end

    def database_shard
      # Ensure we return a symbol that matches our database.yml/connects_to config
      (shard_name.presence || 'default').to_sym
    end

    def page_parts
      Pwb::PagePart.where(page_slug: 'website', website_id: id)
    end

    def get_page_part(page_part_key)
      page_parts.where(page_part_key: page_part_key).first
    end

    def admin_page_links
      if configuration["admin_page_links"].present?
        configuration["admin_page_links"]
      else
        update_admin_page_links
      end
    end

    def update_admin_page_links
      admin_page_links = []
      links.ordered_visible_admin.each do |link|
        admin_page_links.push link.as_json
      end
      configuration["admin_page_links"] = admin_page_links
      save!
      admin_page_links
    end

    def slug
      "website"
    end

    def top_nav_display_links
      links.ordered_top_nav.where(visible: true)
    end

    def footer_display_links
      links.ordered_footer.where(visible: true)
    end

    # ===================
    # External Feed Integration
    # ===================

    # Check if external feeds are enabled for this website
    # @return [Boolean]
    def external_feed_enabled?
      external_feed_enabled && external_feed_provider.present?
    end

    # Get the external feed manager for this website
    # @return [Pwb::ExternalFeed::Manager]
    def external_feed
      @external_feed ||= Pwb::ExternalFeed::Manager.new(self)
    end

    # Configure external feed with a provider and settings
    # @param provider [String, Symbol] Provider name (e.g., :resales_online)
    # @param config [Hash] Provider-specific configuration
    # @param enabled [Boolean] Whether to enable the feed (default: true)
    def configure_external_feed(provider:, config:, enabled: true)
      update!(
        external_feed_enabled: enabled,
        external_feed_provider: provider.to_s,
        external_feed_config: config
      )
    end

    # Disable external feed
    def disable_external_feed
      update!(external_feed_enabled: false)
    end

    # Clear external feed cache
    def clear_external_feed_cache
      external_feed.invalidate_cache if external_feed_enabled?
    end

    # ===================
    # Service Integrations
    # ===================

    # Get the enabled integration for a category
    # @param category [Symbol, String] Integration category (e.g., :ai, :crm)
    # @param provider [Symbol, String, nil] Optional specific provider
    # @return [Pwb::WebsiteIntegration, nil]
    def integration_for(category, provider: nil)
      scope = integrations.enabled.for_category(category)
      scope = scope.by_provider(provider) if provider
      scope.first
    end

    # Check if an integration is configured and enabled
    # @param category [Symbol, String] Integration category
    # @param provider [Symbol, String, nil] Optional specific provider
    # @return [Boolean]
    def integration_configured?(category, provider: nil)
      integration_for(category, provider: provider).present?
    end

    # Get all integrations grouped by category
    # @return [Hash<String, Array<Pwb::WebsiteIntegration>>]
    def integrations_by_category
      integrations.group_by(&:category)
    end

    # ===================
    # Search Configuration
    # ===================

    # Get the search configuration for this website
    # Uses unified configuration that works for both internal and external listings
    #
    # @return [Pwb::SearchConfig]
    def search_configuration
      @search_configuration ||= Pwb::SearchConfig.new(self)
    end

    # Get search configuration for a specific listing type
    #
    # @param listing_type [Symbol, String] The listing type (:sale or :rental)
    # @return [Pwb::SearchConfig]
    def search_configuration_for(listing_type)
      Pwb::SearchConfig.new(self, listing_type: listing_type)
    end

    # Update specific search config keys while preserving existing values
    # This performs a deep merge of the updates with the current configuration
    #
    # @param updates [Hash] Hash of configuration updates
    # @return [Boolean] Whether the update was successful
    # @example
    #   website.update_search_config(
    #     filters: { price: { sale: { presets: [100_000, 200_000] } } },
    #     display: { show_results_map: true }
    #   )
    def update_search_config(updates)
      current = search_config || {}
      self.search_config = deep_merge_hash(current, updates.deep_stringify_keys)
      save
    end

    # Reset search config to empty (will use defaults from SearchConfig)
    #
    # @return [Boolean] Whether the reset was successful
    def reset_search_config
      update(search_config: {})
    end

    private

    # Deep merge two hashes
    #
    # @param base [Hash] Base hash
    # @param override [Hash] Hash to merge in
    # @return [Hash] Merged hash
    def deep_merge_hash(base, override)
      base.deep_merge(override) do |_key, old_val, new_val|
        if old_val.is_a?(Hash) && new_val.is_a?(Hash)
          deep_merge_hash(old_val, new_val)
        else
          new_val
        end
      end
    end

    public

    # ===================
    # Serialization
    # ===================

    def as_json_for_page(options = nil)
      as_json({ only: [],
                methods: ["slug", "page_parts", "page_contents"] }.merge(options || {}))
    end

    def as_json(options = nil)
      super({ only: [
        "company_display_name", "theme_name",
        "default_area_unit", "default_client_locale",
        "available_currencies", "default_currency",
        "supported_locales", "dark_mode_setting"
      ],
              methods: [
                "logo_url", "favicon_url",
                "style_variables", "css_variables",
                "contact_info", "social_links",
                "top_nav_links", "footer_links",
                "agency", "footer_data"
              ] }.merge(options || {}))
    end

    # API helper: Returns all footer-related data in a single object
    def footer_data
      {
        "page_parts" => footer_page_parts,
        "whitelabel" => whitelabel_for_api,
        "admin_url" => admin_url
      }
    end

    # API helper: Returns contact information from agency
    def contact_info
      return {} unless agency

      {
        "phone" => agency.phone_number_primary,
        "phone_mobile" => agency.phone_number_mobile,
        "email" => agency.email_primary,
        "address" => format_agency_address,
        "address_details" => full_agency_address
      }
    end

    # API helper: Returns full address details
    def full_agency_address
      return nil unless agency&.primary_address

      addr = agency.primary_address
      {
        "street_number" => addr.street_number,
        "street_address" => addr.street_address,
        "city" => addr.city,
        "region" => addr.region,
        "postal_code" => addr.postal_code,
        "country" => addr.country,
        "latitude" => addr.latitude,
        "longitude" => addr.longitude
      }.compact
    end

    # API helper: Returns footer page parts (custom HTML content)
    def footer_page_parts
      footer_part = ordered_visible_page_contents&.find_by_page_part_key("footer_content_html")
      return {} unless footer_part&.content

      {
        "footer_content_html" => footer_part.content.raw
      }
    end

    # API helper: Returns whitelabel configuration for API
    def whitelabel_for_api
      config = whitelabel_config || {}
      {
        "show_powered_by" => config["show_powered_by"] != false,
        "powered_by_url" => config["powered_by_url"] || "https://www.propertywebbuilder.com"
      }
    end

    # API helper: Returns admin login URL
    def admin_url
      "/pwb_login"
    end

    # API helper: Returns structured social media links
    def social_links
      {
        "facebook" => social_media_facebook,
        "twitter" => social_media_twitter,
        "instagram" => social_media_instagram,
        "linkedin" => social_media_linkedin,
        "youtube" => social_media_youtube,
        "whatsapp" => social_media_whatsapp,
        "pinterest" => social_media_pinterest
      }.compact
    end

    # API helper: Returns navigation links formatted for API consumption
    def top_nav_links
      links.ordered_visible_top_nav.map(&:as_api_json)
    end

    # API helper: Returns footer links formatted for API consumption
    def footer_links
      links.ordered_visible_footer.map(&:as_api_json)
    end

    private

    def format_agency_address
      return nil unless agency&.primary_address

      [
        agency.street_address,
        agency.city,
        agency.postal_code
      ].compact.reject(&:blank?).join(", ")
    end
  end
end

