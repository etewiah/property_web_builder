module Pwb
  class Prop < ApplicationRecord
    translates :title, :description
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar]


    # Use EUR as model level currency
    register_currency :eur

    # monetize :precio_venta, with_model_currency: :currency, :as => "sales_price", :allow_nil => true
    monetize :price_sale_current_cents, with_model_currency: :currency, :allow_nil => true
    monetize :price_sale_original_cents, with_model_currency: :currency
    monetize :price_rental_monthly_current_cents, with_model_currency: :currency
    monetize :price_rental_monthly_original_cents, with_model_currency: :currency
    monetize :price_rental_monthly_low_season_cents, with_model_currency: :currency
    monetize :price_rental_monthly_high_season_cents, with_model_currency: :currency
    monetize :price_rental_monthly_standard_season_cents, with_model_currency: :currency

    monetize :commission_cents, with_model_currency: :currency
    monetize :service_charge_yearly_cents, with_model_currency: :currency
    # monetize :price_in_a_range_cents, with_model_currency: :currency, :allow_nil => true,
    # :numericality => {
    #   :greater_than_or_equal_to => 0,
    #   :less_than_or_equal_to => 10000
    # }

    validates :reference, :uniqueness => { case_sensitive: false }

    has_many :prop_photos, -> { order 'sort_order asc' }


    scope :for_rent, -> () { where('for_rent_short_term OR for_rent_long_term') }
    # couldn't do above if for_rent_short_term was a flatshihtzu boolean
    scope :for_sale, -> () { where for_sale: true }
    scope :visible, -> () { where visible: true }

    def has_garage
      self.count_garages && (self.count_garages > 0)
    end

    def for_rent
      return self.for_rent_short_term || self.for_rent_long_term
    end

    def show_map
      if self.latitude.present? && self.longitude.present?
        return !self.hide_map
      else
        return false
      end
    end

    def ordered_photo_url number
      # allows me to pick an individual image according to an order
      unless self.prop_photos.length >= number
        return "https://placeholdit.imgix.net/~text?txtsize=38&txt=&w=550&h=400&txttrack=0"
      end
      return self.prop_photos[number - 1].image.url
    end

    def url_friendly_title
      # used in constructing seo friendly url
      if self.title && self.title.length > 2
        return self.title.parameterize
      else
        return "show"
      end
    end

    def contextual_show_path rent_or_sale
      unless rent_or_sale
        # where I am displaying items searched by ref number, won't know if its for sale or rent beforehand
        rent_or_sale = self.for_rent ? "for_rent" : "for_sale"
      end
      if rent_or_sale == "for_rent"
        return Pwb::Engine.routes.url_helpers.prop_show_for_rent_path(locale: I18n.locale, id: self.id, url_friendly_title: self.url_friendly_title)
      else
        return Pwb::Engine.routes.url_helpers.prop_show_for_sale_path(locale: I18n.locale, id: self.id, url_friendly_title: self.url_friendly_title)
      end
    end

    def contextual_price rent_or_sale
      unless rent_or_sale
        # where I am displaying items searched by ref number, won't know if its for sale or rent beforehand
        rent_or_sale = self.for_rent ? "for_rent" : "for_sale"
      end
      if rent_or_sale == "for_rent"
        # || rent_or_sale == "forRent"
        contextual_price = self.price_rental_monthly_for_search
        # contextual_price = self.rental_price
      else
        contextual_price = self.price_sale_current
      end
      return contextual_price
      # .zero? ? nil : contextual_price.format(:no_cents => true)
    end


    # will return nil if price is 0
    def contextual_price_with_currency rent_or_sale
      contextual_price = self.contextual_price rent_or_sale

      if contextual_price.zero?
        return nil
      else
        return contextual_price.format(:no_cents => true)
      end

      # return contextual_price.zero? ? nil : contextual_price.format(:no_cents => true)
    end



  end
end
