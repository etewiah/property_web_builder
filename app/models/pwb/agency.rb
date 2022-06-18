module Pwb
  class Agency < ApplicationRecord
    before_create :confirm_singularity

    # extend ActiveHash::Associations::ActiveRecordExtensions

    # belongs_to_active_hash :theme, foreign_key: "theme_name", class_name: "Pwb::Theme", shortcuts: [:friendly_name], primary_key: "name"

    belongs_to :primary_address, optional: true, class_name: "Address", foreign_key: "primary_address_id"
    belongs_to :secondary_address, optional: true, class_name: "Address", foreign_key: "secondary_address_id"

    def self.unique_instance
      # there will be only one row, and its ID must be '1'

      # TODO: - memoize
      find(1)
    rescue ActiveRecord::RecordNotFound
      # slight race condition here, but it will only happen once
      row = Agency.new
      row.id = 1
      row.save!
      row
    end

    def as_json(options = nil)
      super({ only: [
        "display_name", "company_name",
        # "theme_name",
        "phone_number_primary", "phone_number_mobile", "phone_number_other",
        # "social_media", "default_client_locale",
        # "default_admin_locale", "raw_css", "analytics_id",
        "email_primary", "email_for_property_contact_form", "email_for_general_contact_form",
      # "available_currencies", "default_currency",
      # "supported_locales", "available_locales"
      ]
 # methods: ["style_variables"]
         }.merge(options || {}))
    end

    def street_number
      primary_address.present? ? primary_address.street_number : nil
    end

    def street_address
      primary_address.present? ? primary_address.street_address : nil
    end

    def city
      primary_address.present? ? primary_address.city : nil
    end

    def postal_code
      primary_address.present? ? primary_address.postal_code : nil
    end

    # def default_client_locale_to_use
    #   if supported_locales.count == 1
    #     locale = supported_locales.first.split("-")[0]
    #   else
    #     locale = default_client_locale || :en
    #   end
    #   locale
    # end

    def show_contact_map
      primary_address.present?
    end

    # def views_folder
    #   views_folder = "/pwb/themes/standard"
    #   # if self.site_template.present? && self.site_template.views_folder
    #   #   views_folder = self.site_template.views_folder
    #   # end
    #   return views_folder
    # end

    # def style_variables
    #   default_style_variables = {
    #     "primary_color" => "#e91b23", # red
    #     "secondary_color" => "#3498db", # blue
    #     "action_color" => "green",
    #     "body_style" => "siteLayout.wide",
    #     "theme" => "light"
    #   }
    #   details["style_variables"] || default_style_variables
    # end

    # def style_variables=(style_variables)
    #   details["style_variables"] = style_variables
    # end

    # def social_media=(social_media)
    #   if social_media
    #    # && social_media.keys.length > 0
    #     self.social_media = social_media
    #   end
    # end

    private

    def confirm_singularity
      raise Exception, "There can be only one agency." if Agency.count > 0
    end
  end
end
