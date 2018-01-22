module Pwb
  class Website < ApplicationRecord
    extend ActiveHash::Associations::ActiveRecordExtensions
    belongs_to_active_hash :theme, optional: true, foreign_key: "theme_name", class_name: "Pwb::Theme", shortcuts: [:friendly_name], primary_key: "name"


    has_many :page_contents
    has_many :contents, :through => :page_contents
    # https://stackoverflow.com/questions/5856838/scope-with-join-on-has-many-through-association
    has_many :ordered_visible_page_contents, -> { ordered_visible }, :class_name => 'PageContent'
    # has_many :page_parts, -> { where(page_slug: :footer) }
    # , foreign_key: "page_slug", primary_key: "slug", class_name: "Pwb::Link"


    # TODO - add favicon image (and logo image directly)
    # as well as details hash for storing pages..

    include FlagShihTzu

    has_flags 1 => :landing_hide_for_rent,
      2 => :landing_hide_for_sale,
      3 => :landing_hide_search_bar

    def self.unique_instance
      # there will be only one row, and its ID must be '1'
      begin
        # TODO - memoize
        find(1)
      rescue ActiveRecord::RecordNotFound
        # slight race condition here, but it will only happen once
        row = Website.new
        row.id = 1
        row.save!
        row
      end
    end

    def page_parts 
      return Pwb::PagePart.where(page_slug: "website")
    end

    def get_page_part page_part_key
      # byebug
      page_parts.where(page_part_key: page_part_key).first 
    end

    # These are a list of links for pages to be
    # displayed in the pages section of the
    # admin site
    def admin_page_links
      #
      if self.configuration["admin_page_links"].present?
        return configuration["admin_page_links"]
      else
        return update_admin_page_links
      end
    end

    # TODO - call this each time a page
    # needs to be added or
    # deleted from admin
    # jan 2018 - currently if a link title is updated
    # the admin_page_links cached in configuration
    # do not get updated
    def update_admin_page_links
      admin_page_links = []
      Pwb::Link.ordered_visible_admin.each do |link|
        admin_page_links.push link.as_json
      end
      self.configuration["admin_page_links"] = admin_page_links
      self.save!
      return admin_page_links
    end

    def as_json(options = nil)
      super({only: [
               "company_display_name", "theme_name",
               "default_area_unit", "default_client_locale",
               "available_currencies", "default_currency",
               "supported_locales", "social_media",
               "raw_css", "analytics_id", "analytics_id_type",
               "sale_price_options_from", "sale_price_options_till",
               "rent_price_options_from", "rent_price_options_till"
             ],
             methods: ["style_variables","admin_page_links"]}.merge(options || {}))
    end

    enum default_area_unit: { sqmt: 0, sqft: 1 }

    def is_multilingual
      supported_locales.length > 1
    end

    def supported_locales_with_variants
      supported_locales_with_variants = []
      self.supported_locales.each do |supported_locale|
        slwv_array = supported_locale.split("-")
        locale = slwv_array[0] || "en"
        variant = slwv_array[1] || slwv_array[0]|| "UK"
        slwv = { "locale" => locale, "variant" => variant.downcase }
        supported_locales_with_variants.push slwv
      end
      return supported_locales_with_variants
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
        "theme" => "light"
      }
      style_variables_for_theme["default"] || default_style_variables
    end

    def style_variables=(style_variables)
      style_variables_for_theme["default"] = style_variables
    end
    # spt 2017 - above 2 will be redundant once vic becomes default layout



    # below used when rendering to decide which class names
    # to use for which elements
    def get_element_class element_name
      style_details = style_variables_for_theme["vic"] || Pwb::PresetStyle.default_values
      style_associations = style_details["associations"] || []
      style_associations[element_name] || ""
    end

    # below used by custom stylesheet generator to decide
    # values for various class names (mainly colors)
    def get_style_var var_name
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
      logo_content = Content.find_by_key("logo")
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
  end
end
