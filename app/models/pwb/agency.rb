module Pwb
  class Agency < ApplicationRecord
    before_create :confirm_singularity

    extend ActiveHash::Associations::ActiveRecordExtensions

    belongs_to_active_hash :theme, foreign_key: "theme_name", class_name: "Pwb::Theme", shortcuts: [:friendly_name], primary_key: "name"

    belongs_to :primary_address, class_name: "Address", foreign_key: 'primary_address_id'
    belongs_to :secondary_address, class_name: "Address", foreign_key: 'secondary_address_id'

    # def supported_languages
    #   return self.supported_locales.present? ? self.supported_locales : ["en"]
    # end
    def as_json(options = nil)
      super({:only =>[
               "display_name", "company_name", "theme_name",
               "phone_number_primary","phone_number_mobile","phone_number_other",
               "social_media","default_client_locale",
               "default_admin_locale","raw_css","analytics_id",
               "email_primary","email_for_property_contact_form", "email_for_general_contact_form",
               "available_currencies","default_currency",
               "supported_locales","available_locales"
             ],
             :methods => ["style_variables"]}.merge(options || {}))
    end


    def is_multilingual
      return self.supported_locales.length > 1
    end

    def default_client_locale_to_use
      locale = self.default_client_locale || :en
      return locale
    end

    def show_contact_map
      return self.primary_address.present?
    end

    # def views_folder
    #   views_folder = "/pwb/themes/standard"
    #   # if self.site_template.present? && self.site_template.views_folder
    #   #   views_folder = self.site_template.views_folder
    #   # end
    #   return views_folder
    # end

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

    # def social_media=(social_media)
    #   if social_media
    #    # && social_media.keys.length > 0
    #     self.social_media = social_media
    #   end
    # end

    def body_style
      body_style = ""
      if self.details["style_variables"] && (self.details["style_variables"]["body_style"] == "siteLayout.boxed")
        body_style = "body-boxed"
      end
      return body_style
    end

    def logo_url
      logo_url = nil
      logo_content = Content.find_by_key("logo")
      if logo_content && logo_content.content_photos.length > 0
        logo_url = logo_content.content_photos.first.image_url
      end
      return logo_url
    end

    private

    def confirm_singularity
      raise Exception.new("There can be only one agency.") if Agency.count > 0
    end
  end
end
