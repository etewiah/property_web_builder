# frozen_string_literal: true

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
    has_many :contacts, class_name: 'Pwb::Contact'
    has_many :messages, class_name: 'Pwb::Message'
    has_many :website_photos
    has_many :field_keys, class_name: 'Pwb::FieldKey', foreign_key: :pwb_website_id
    has_many :email_templates, class_name: 'Pwb::EmailTemplate', dependent: :destroy

    # Media Library
    has_many :media, class_name: 'Pwb::Media', dependent: :destroy
    has_many :media_folders, class_name: 'Pwb::MediaFolder', dependent: :destroy

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
        "supported_locales", "social_media",
        "raw_css", "analytics_id", "analytics_id_type",
        "sale_price_options_from", "sale_price_options_till",
        "rent_price_options_from", "rent_price_options_till",
      ],
              methods: ["style_variables", "admin_page_links", "top_nav_display_links",
                        "footer_display_links", "agency"] }.merge(options || {}))
    end
  end
end
