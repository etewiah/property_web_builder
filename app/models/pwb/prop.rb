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
    monetize :price_rental_monthly_for_search_cents, with_model_currency: :currency

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


    scope :in_zone, -> (key) { where zone_key: key}
    scope :in_locality, -> (key) { where locality_key: key}

    scope :property_type, -> (property_type) { where prop_type_key: property_type }
    scope :property_state, -> (property_state) { where prop_state_key: property_state }
    # scope :property_type, -> (property_type) { where property_type: property_type }
    # scope :property_state, -> (property_state) { where property_state: property_state }
    # below scopes used for searching
    scope :for_rent_price_from, -> (minimum_price) { where("price_rental_monthly_for_search_cents >= ?", "#{minimum_price}")}
    scope :for_rent_price_till, -> (maximum_price) { where("price_rental_monthly_for_search_cents <= ?", "#{maximum_price}")}
    scope :for_sale_price_from, -> (minimum_price) { where("price_sale_current_cents >= ?", "#{minimum_price}")}
    scope :for_sale_price_till, -> (maximum_price) { where("price_sale_current_cents <= ?", "#{maximum_price}")}
    scope :count_bathrooms, -> (min_count_bathrooms) { where("count_bathrooms >= ?", "#{min_count_bathrooms}")}
    scope :count_bedrooms, -> (min_count_bedrooms) { where("count_bedrooms >= ?", "#{min_count_bedrooms}")}
    # scope :starts_with, -> (name) { where("name like ?", "#{name}%")}
    # scope :pending, joins(:admin_request_status).where('admin_request_statuses.name = ?','Pending Approval')




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

    def rental_price
      # deliberately checking short_term first
      # so that it overrides long_term price if both are set
      if self.for_rent_short_term
        rental_price = self.lowest_short_term_price || 0
      elsif self.for_rent_long_term
        rental_price = self.price_rental_monthly_current || 0
      end
      unless rental_price && rental_price > 0
        return nil
      end
      return rental_price
    end

    def lowest_short_term_price
      prices_array = [self.price_rental_monthly_low_season, self.price_rental_monthly_standard_season, self.price_rental_monthly_high_season]
      # remove any prices that are 0:
      prices_array.reject! { |a| a.cents < 1 }
      return prices_array.min
    end

    before_save :set_rental_search_price

    private

    # called from before_save
    def set_rental_search_price
      # below for setting a value that I can use for searcing and ordering rental properties
      self.price_rental_monthly_for_search = self.rental_price
    end


  end
end
