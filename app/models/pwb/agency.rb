module Pwb
  class Agency < ApplicationRecord
    before_create :confirm_singularity

    belongs_to :primary_address, :class_name => "Address", :foreign_key => 'primary_address_id'
    belongs_to :secondary_address, :class_name => "Address", :foreign_key => 'secondary_address_id'

    # TODO - replace below with supported_locales
    def supported_languages
      return self.supported_locales.present? ? self.supported_locales : ["en"]
    end

    def is_multilingual
      return self.supported_languages.length > 1
    end

    def default_client_locale_to_use
      # If only 1 language is supported, use that as default
      locale = self.supported_locales.present? ? self.supported_locales.first : "en"
      if (self.supported_languages.length > 1) && self.default_client_locale.present?
        locale = self.default_client_locale
      end
      return locale
    end

    def show_contact_map
      return self.primary_address.present?
    end

    def views_folder
      views_folder = "/pwb/themes/standard"
      # if self.site_template.present? && self.site_template.views_folder
      #   views_folder = self.site_template.views_folder
      # end
      return views_folder
    end

    def custom_css_file
      custom_css_file = "standard"
      # if self.site_template.present? && self.site_template.custom_css_file
      #   custom_css_file = self.site_template.custom_css_file
      # end
      return custom_css_file
    end


    def style_variables
      default_style_variables = {
        "primary_color" => "#e91b23", #red
        "secondary_color" => "#3498db", #blue
        "action_color" => "green",
        "body_style" => "siteLayout.wide",
        "theme" => "light"
      }
      return self.details["style_variables"] || default_style_variables
    end

    def style_variables=(style_variables)
      self.details["style_variables"] = style_variables
    end

    def social_media=(social_media)
      if social_media
       # && social_media.keys.length > 0
        self.details["social_media"] = social_media
      end
    end

    def body_style
      body_style = ""
      if self.details["style_variables"] && (self.details["style_variables"]["body_style"] == "siteLayout.boxed")
        body_style = "body-boxed"
      end
      return body_style
    end


    private

    def confirm_singularity
      raise Exception.new("There can be only one agency.") if Agency.count > 0
    end
  end
end
