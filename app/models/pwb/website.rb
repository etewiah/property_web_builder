module Pwb
  class Website < ApplicationRecord
    extend ActiveHash::Associations::ActiveRecordExtensions
    belongs_to_active_hash :theme, optional: true, foreign_key: "theme_name", class_name: "Pwb::Theme", shortcuts: [:friendly_name], primary_key: "name"

    has_many :page_contents
    has_many :contents, through: :page_contents
    # https://stackoverflow.com/questions/5856838/scope-with-join-on-has-many-through-association
    has_many :ordered_visible_page_contents, -> { ordered_visible }, class_name: "Pwb::PageContent"

    has_many :props
    has_many :realty_assets, class_name: 'Pwb::RealtyAsset', foreign_key: 'website_id'
    has_many :sale_listings, through: :realty_assets
    has_many :rental_listings, through: :realty_assets
    
    has_many :pages
    has_many :contents
    has_many :links
    has_many :users
    has_many :contacts
    has_many :messages
    has_many :website_photos
    has_many :field_keys, foreign_key: :pwb_website_id

    # Multi-website support via memberships
    has_many :user_memberships, dependent: :destroy
    has_many :members, through: :user_memberships, source: :user

    has_one :agency

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

    def page_parts
      # Filter by website_id for multi-tenant isolation
      Pwb::PagePart.where(page_slug: "website", website_id: id)
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

    # spt 2017 - above 2 will be redundant once vic becomes default layout

    # below used when rendering to decide which class names
    # to use for which elements
    def get_element_class(element_name)
      style_details = style_variables_for_theme["vic"] || Pwb::PresetStyle.default_values
      style_associations = style_details["associations"] || []
      style_associations[element_name] || ""
    end

    # below used by custom stylesheet generator to decide
    # values for various class names (mainly colors)
    def get_style_var(var_name)
      style_details = style_variables_for_theme["vic"] || Pwb::PresetStyle.default_values
      style_vars = style_details["variables"] || []
      style_vars[var_name] || ""
    end

    # allow direct bulk setting of styles from admin UI
    def style_settings=(style_settings)
      style_variables_for_theme["vic"] = style_settings
    end

    # allow setting of styles to a preset config from admin UI
    def style_settings_from_preset=(preset_style_name)
      preset_style = Pwb::PresetStyle.where(name: preset_style_name).first
      if preset_style
        style_variables_for_theme["vic"] = preset_style.attributes.as_json
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

    private

    def subdomain_not_reserved
      return if subdomain.blank?
      if RESERVED_SUBDOMAINS.include?(subdomain.downcase)
        errors.add(:subdomain, "is reserved and cannot be used")
      end
    end
  end
end
