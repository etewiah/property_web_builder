module Pwb
  class Website < ApplicationRecord
    include AASM

    extend ActiveHash::Associations::ActiveRecordExtensions
    belongs_to_active_hash :theme, optional: true, foreign_key: "theme_name", class_name: "Pwb::Theme", shortcuts: [:friendly_name], primary_key: "name"

    has_many :page_contents, class_name: 'Pwb::PageContent'
    has_many :contents, through: :page_contents, class_name: 'Pwb::Content'
    # https://stackoverflow.com/questions/5856838/scope-with-join-on-has-many-through-association
    has_many :ordered_visible_page_contents, -> { ordered_visible }, class_name: 'Pwb::PageContent'

    # Listed properties from the materialized view (read-only, for display)
    has_many :listed_properties, class_name: 'Pwb::ListedProperty', foreign_key: 'website_id'
    # Legacy Prop model - kept for backwards compatibility with existing code/tests
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

    # Multi-website support via memberships
    has_many :user_memberships, dependent: :destroy
    has_many :members, through: :user_memberships, source: :user

    has_one :agency, class_name: 'Pwb::Agency'
    has_one :allocated_subdomain, class_name: 'Pwb::Subdomain', foreign_key: 'website_id'

    # Site types for content customization
    SITE_TYPES = %w[residential commercial vacation_rental].freeze

    validates :site_type, inclusion: { in: SITE_TYPES }, allow_blank: true

    # Provisioning state machine
    aasm column: :provisioning_state do
      state :pending, initial: true
      state :subdomain_allocated
      state :configuring
      state :seeding
      state :ready
      state :live
      state :failed
      state :suspended
      state :terminated

      event :allocate_subdomain do
        transitions from: :pending, to: :subdomain_allocated
        after do
          update!(provisioning_started_at: Time.current) if provisioning_started_at.blank?
        end
      end

      event :start_configuring do
        transitions from: :subdomain_allocated, to: :configuring
      end

      event :start_seeding do
        transitions from: :configuring, to: :seeding
      end

      event :mark_ready do
        transitions from: :seeding, to: :ready
        after do
          update!(provisioning_completed_at: Time.current)
        end
      end

      event :go_live do
        transitions from: :ready, to: :live
      end

      event :fail_provisioning do
        transitions from: [:pending, :subdomain_allocated, :configuring, :seeding], to: :failed
        after do |error_message|
          update!(provisioning_error: error_message)
        end
      end

      event :retry_provisioning do
        transitions from: :failed, to: :pending
        after do
          update!(provisioning_error: nil)
        end
      end

      event :suspend do
        transitions from: [:ready, :live], to: :suspended
      end

      event :reactivate do
        transitions from: :suspended, to: :live
      end

      event :terminate do
        transitions from: [:suspended, :failed], to: :terminated
      end
    end

    # Provisioning progress as percentage (for progress bar)
    def provisioning_progress
      case provisioning_state
      when 'pending' then 0
      when 'subdomain_allocated' then 20
      when 'configuring' then 40
      when 'seeding' then 70
      when 'ready' then 95
      when 'live' then 100
      else 0
      end
    end

    # Human-readable provisioning status message
    def provisioning_status_message
      case provisioning_state
      when 'pending' then 'Waiting to start...'
      when 'subdomain_allocated' then 'Subdomain assigned'
      when 'configuring' then 'Setting up your website...'
      when 'seeding' then 'Adding sample properties...'
      when 'ready' then 'Almost done! Finalizing...'
      when 'live' then 'Your website is live!'
      when 'failed' then "Setup failed: #{provisioning_error}"
      when 'suspended' then 'Website suspended'
      when 'terminated' then 'Website terminated'
      else 'Unknown status'
      end
    end

    # Check if website is accessible to visitors
    def accessible?
      live? || ready?
    end

    # Check if still being provisioned
    def provisioning?
      %w[pending subdomain_allocated configuring seeding].include?(provisioning_state)
    end

    def admins
      members.where(pwb_user_memberships: { role: ['owner', 'admin'], active: true })
    end

    # Subdomain validations
    validates :subdomain,
              uniqueness: { case_sensitive: false, allow_blank: true },
              format: {
                with: /\A[a-z0-9]([a-z0-9\-]*[a-z0-9])?\z/i,
                message: "can only contain alphanumeric characters and hyphens, and cannot start or end with a hyphen",
                allow_blank: true
              },
              length: { minimum: 2, maximum: 63, allow_blank: true }

    # Reserved subdomains that cannot be used by tenants
    RESERVED_SUBDOMAINS = %w[www api admin app mail ftp smtp pop imap ns1 ns2 localhost staging test demo].freeze

    validate :subdomain_not_reserved

    # Custom domain validations
    validates :custom_domain,
              uniqueness: { case_sensitive: false, allow_blank: true },
              format: {
                with: /\A([a-z0-9]([a-z0-9\-]*[a-z0-9])?\.)+[a-z]{2,}\z/i,
                message: "must be a valid domain name (e.g., www.example.com or example.com)",
                allow_blank: true
              },
              length: { maximum: 253, allow_blank: true }

    validate :custom_domain_not_platform_domain

    # TODO: - add favicon image (and logo image directly)

    # as well as details hash for storing pages..

    include FlagShihTzu

    has_flags 1 => :landing_hide_for_rent,
      2 => :landing_hide_for_sale,
      3 => :landing_hide_search_bar

    # Find a website by subdomain (case-insensitive)
    def self.find_by_subdomain(subdomain)
      return nil if subdomain.blank?
      where("LOWER(subdomain) = ?", subdomain.downcase).first
    end

    # Find a website by custom domain (case-insensitive, handles www prefix)
    def self.find_by_custom_domain(domain)
      return nil if domain.blank?

      normalized = normalize_domain(domain)

      # Try exact match first
      website = where("LOWER(custom_domain) = ?", normalized.downcase).first
      return website if website

      # Try with www prefix if not present, or without if present
      if normalized.start_with?('www.')
        where("LOWER(custom_domain) = ?", normalized.sub(/\Awww\./, '').downcase).first
      else
        where("LOWER(custom_domain) = ?", "www.#{normalized}".downcase).first
      end
    end

    # Find a website by either subdomain or custom domain based on the host
    # This is the primary lookup method used by the routing concern
    def self.find_by_host(host)
      return nil if host.blank?

      host = host.to_s.downcase.strip

      # First try custom domain lookup (for non-platform domains)
      unless platform_domain?(host)
        website = find_by_custom_domain(host)
        return website if website
      end

      # Fall back to subdomain lookup (extract first part of host)
      subdomain = extract_subdomain_from_host(host)
      find_by_subdomain(subdomain) if subdomain.present?
    end

    # Normalize a domain by removing protocol, path, and optionally www
    def self.normalize_domain(domain)
      domain.to_s.downcase.strip
            .sub(%r{\Ahttps?://}, '')  # Remove protocol
            .sub(%r{/.*\z}, '')        # Remove path
            .sub(/:\d+\z/, '')         # Remove port
    end

    # Check if a host is a platform domain (where subdomains route to tenants)
    def self.platform_domain?(host)
      platform_domains.any? { |pd| host.end_with?(pd) }
    end

    # Extract subdomain from a platform domain host
    def self.extract_subdomain_from_host(host)
      platform_domains.each do |pd|
        if host.end_with?(pd)
          # Remove the platform domain to get the subdomain
          subdomain_part = host.sub(/\.?#{Regexp.escape(pd)}\z/, '')
          # Take the first part if there are multiple levels
          return subdomain_part.split('.').first if subdomain_part.present?
        end
      end
      nil
    end

    # Get list of platform domains from configuration
    def self.platform_domains
      ENV.fetch('PLATFORM_DOMAINS', 'propertywebbuilder.com,pwb.localhost,e2e.localhost,localhost').split(',').map(&:strip)
    end

    def page_parts
      # Filter by website_id for multi-tenant isolation
      Pwb::PagePart.where(page_slug: 'website', website_id: id)
    end

    def get_page_part(page_part_key)
      # Only return page parts that belong to this website
      page_parts.where(page_part_key: page_part_key).first
    end

    # These are a list of links for pages to be
    # displayed in the pages section of the
    # admin site
    # TODO: feb 2018 - enable management of
    # below via /config path
    def admin_page_links
      #
      if configuration["admin_page_links"].present?
        configuration["admin_page_links"]
      else
        update_admin_page_links
      end
    end

    # TODO: - call this each time a page
    # needs to be added or
    # deleted from admin
    # jan 2018 - currently if a link title is updated
    # the admin_page_links cached in configuration
    # do not get updated
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
      # slug is needed for
      # admin client side page model
      "website"
    end

    def as_json_for_page(options = nil)
      # Sends data to admin in format compatible
      # with client side page model
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
              methods: ["style_variables", "admin_page_links", "top_nav_display_links", "footer_display_links", "agency"] }.merge(options || {}))
    end

    enum :default_area_unit, { sqmt: 0, sqft: 1 }

    def is_multilingual
      supported_locales.length > 1
    end

    def supported_locales_with_variants
      supported_locales_with_variants = []
      supported_locales.each do |supported_locale|
        slwv_array = supported_locale.split("-")
        locale = slwv_array[0] || "en"
        variant = slwv_array[1] || slwv_array[0] || "UK"
        slwv = { "locale" => locale, "variant" => variant.downcase }
        supported_locales_with_variants.push slwv
      end
      supported_locales_with_variants
    end

    def default_client_locale_to_use
      locale = default_client_locale || "en-UK"
      if supported_locales && supported_locales.count == 1
        locale = supported_locales.first
      end
      locale.split("-")[0]
    end

    # admin client & default.css.erb uses style_variables
    # but it is stored in style_variables_for_theme json col
    # In theory, could have different style_variables per theme but not
    # doing that right now
    def style_variables
      default_style_variables = {
        "primary_color" => "#e91b23", # red
        "secondary_color" => "#3498db", # blue
        "action_color" => "green",
        "body_style" => "siteLayout.wide",
        "theme" => "light",
        "font_primary" => "Open Sans",
        "font_secondary" => "Vollkorn",
        "border_radius" => "0.5rem",
        "container_padding" => "1rem",
      }
      style_variables_for_theme["default"] || default_style_variables
    end

    def style_variables=(style_variables)
      style_variables_for_theme["default"] = style_variables
    end

    # below used when rendering to decide which class names
    # to use for which elements
    def get_element_class(element_name)
      style_details = style_variables_for_theme["default"] || Pwb::PresetStyle.default_values
      style_associations = style_details["associations"] || []
      style_associations[element_name] || ""
    end

    # below used by custom stylesheet generator to decide
    # values for various class names (mainly colors)
    def get_style_var(var_name)
      style_details = style_variables_for_theme["default"] || Pwb::PresetStyle.default_values
      style_vars = style_details["variables"] || []
      style_vars[var_name] || ""
    end

    # allow direct bulk setting of styles from admin UI
    def style_settings=(style_settings)
      style_variables_for_theme["default"] = style_settings
    end

    # allow setting of styles to a preset config from admin UI
    def style_settings_from_preset=(preset_style_name)
      preset_style = Pwb::PresetStyle.where(name: preset_style_name).first
      if preset_style
        style_variables_for_theme["default"] = preset_style.attributes.as_json
      end
    end

    def body_style
      body_style = ""
      if style_variables_for_theme["default"] && (style_variables_for_theme["default"]["body_style"] == "siteLayout.boxed")
        body_style = "body-boxed"
      end
      body_style
    end

    # def custom_css_file
    #   # used by css_controller to decide which file to compile
    #   # with user set variables.
    #   #
    #   custom_css_file = "standard"
    #   # if self.site_template.present? && self.site_template.custom_css_file
    #   #   custom_css_file = self.site_template.custom_css_file
    #   # end
    #   custom_css_file
    # end

    def logo_url
      logo_url = nil
      logo_content = contents.find_by_key("logo")
      if logo_content && !logo_content.content_photos.empty?
        logo_url = logo_content.content_photos.first.image_url
      end
      logo_url
    end

    def theme_name=(theme_name_value)
      theme_with_name_exists = Pwb::Theme.where(name: theme_name_value).count > 0
      if theme_with_name_exists
        write_attribute(:theme_name, theme_name_value)
        # this is same as self[:theme_name] = theme_name_value
      end
    end

    def render_google_analytics
      Rails.env.production? && analytics_id.present?
    end

    def top_nav_display_links
      links.ordered_top_nav.where(visible: true)
    end

    def footer_display_links
      links.ordered_footer.where(visible: true)
    end

    # NOTE: The agency method is provided by the has_one :agency association
    # defined at the top of this class. Each website has its own agency.

    def social_media_facebook
      links.find_by(slug: "social_media_facebook")&.link_url
    end

    def social_media_twitter
      links.find_by(slug: "social_media_twitter")&.link_url
    end

    def social_media_linkedin
      links.find_by(slug: "social_media_linkedin")&.link_url
    end

    def social_media_youtube
      links.find_by(slug: "social_media_youtube")&.link_url
    end

    def social_media_pinterest
      links.find_by(slug: "social_media_pinterest")&.link_url
    end

    # Generate a unique token for DNS verification of custom domain
    def generate_domain_verification_token!
      update!(custom_domain_verification_token: SecureRandom.hex(16))
    end

    # Verify custom domain ownership via DNS TXT record
    # Returns true if verified, false otherwise
    def verify_custom_domain!
      return false if custom_domain.blank? || custom_domain_verification_token.blank?

      begin
        require 'resolv'
        resolver = Resolv::DNS.new

        # Look for TXT record at _pwb-verification.example.com
        verification_host = "_pwb-verification.#{custom_domain.sub(/\Awww\./, '')}"
        txt_records = resolver.getresources(verification_host, Resolv::DNS::Resource::IN::TXT)

        verified = txt_records.any? { |record| record.strings.join == custom_domain_verification_token }

        if verified
          update!(
            custom_domain_verified: true,
            custom_domain_verified_at: Time.current
          )
        end

        verified
      rescue Resolv::ResolvError, Resolv::ResolvTimeout => e
        Rails.logger.warn("Domain verification failed for #{custom_domain}: #{e.message}")
        false
      end
    end

    # Check if custom domain is verified or if we allow unverified domains (dev mode)
    def custom_domain_active?
      return false if custom_domain.blank?
      custom_domain_verified? || Rails.env.development? || Rails.env.test?
    end

    # Get the primary URL for this website
    def primary_url
      if custom_domain.present? && custom_domain_active?
        "https://#{custom_domain}"
      elsif subdomain.present?
        platform_domain = self.class.platform_domains.first
        "https://#{subdomain}.#{platform_domain}"
      else
        nil
      end
    end

    private

    def subdomain_not_reserved
      return if subdomain.blank?
      if RESERVED_SUBDOMAINS.include?(subdomain.downcase)
        errors.add(:subdomain, "is reserved and cannot be used")
      end
    end

    def custom_domain_not_platform_domain
      return if custom_domain.blank?

      self.class.platform_domains.each do |pd|
        if custom_domain.downcase.end_with?(pd)
          errors.add(:custom_domain, "cannot be a platform domain (#{pd})")
          return
        end
      end
    end
  end
end
