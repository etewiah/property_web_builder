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
             ],
             methods: ["style_variables"]}.merge(options || {}))
    end

    def default_client_locale_to_use
      if supported_locales.count == 1
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

  end
end
