module Pwb
  class Website < ApplicationRecord
    extend ActiveHash::Associations::ActiveRecordExtensions
    belongs_to_active_hash :theme, foreign_key: "theme_name", class_name: "Pwb::Theme", shortcuts: [:friendly_name], primary_key: "name"

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

    def as_json(options = nil)
      super({only: [
               "company_display_name", "theme_name",
               "default_area_unit", "default_client_locale",
               "available_currencies", "default_currency",
               "supported_locales", "social_media"
             ],
             methods: ["style_variables"]}.merge(options || {}))
    end

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
      if supported_locales && supported_locales.count == 1
        locale = supported_locales.first.split("-")[0]
      else
        locale = default_client_locale || :en
      end
      locale
    end

    def style_variables
      default_style_variables = {
        "primary_color" => "#e91b23", # red
        "secondary_color" => "#3498db", # blue
        "action_color" => "green",
        "body_style" => "siteLayout.wide",
        "theme" => "light"
      }
      style_variables_for_theme["style_variables"] || default_style_variables
    end

    def style_variables=(style_variables)
      style_variables_for_theme["style_variables"] = style_variables
    end

    def body_style
      body_style = ""
      if style_variables_for_theme["style_variables"] && (style_variables_for_theme["style_variables"]["body_style"] == "siteLayout.boxed")
        body_style = "body-boxed"
      end
      body_style
    end

    def custom_css_file
      # used by css_controller to decide which file to compile
      # with user set variables.
      # 
      custom_css_file = "standard"
      # if self.site_template.present? && self.site_template.custom_css_file
      #   custom_css_file = self.site_template.custom_css_file
      # end
      custom_css_file
    end

    def logo_url
      logo_url = nil
      logo_content = Content.find_by_key("logo")
      if logo_content && !logo_content.content_photos.empty?
        logo_url = logo_content.content_photos.first.image_url
      end
      logo_url
    end
  end
end
