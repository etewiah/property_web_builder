module Pwb
  class Prop < ApplicationRecord
    translates :title, :description
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar]

    scope :for_rent, -> () { where('for_rent_short_term OR for_rent_long_term') }
    # couldn't do above if for_rent_short_term was a flatshihtzu boolean
    scope :for_sale, -> () { where for_sale: true }
    scope :visible, -> () { where visible: true }

    def has_garage
      self.count_garages && (self.count_garages > 0)
    end


    # def contextual_show_path rent_or_sale
    #   unless rent_or_sale
    #     # where I am displaying items searched by ref number, won't know if its for sale or rent beforehand
    #     rent_or_sale = self.for_rent ? "for_rent" : "for_sale"
    #   end
    #   if rent_or_sale == "for_rent"
    #     return Rails.application.routes.url_helpers.property_show_for_rent_path(locale: I18n.locale, id: self.id, url_friendly_title: self.url_friendly_title)
    #   else
    #     return Rails.application.routes.url_helpers.property_show_for_sale_path(locale: I18n.locale, id: self.id, url_friendly_title: self.url_friendly_title)
    #   end
    # end
  end
end
