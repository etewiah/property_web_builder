module Pwb
  class Prop < ApplicationRecord
    translates :title, :description
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]

    # Use EUR as model level currency
    # register_currency :eur

    # monetize :precio_venta, with_model_currency: :currency, :as => "sales_price", :allow_nil => true
    monetize :price_sale_current_cents, with_model_currency: :currency, allow_nil: true
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

    # TODO: - Ensure admin client can warn of uniqueness errors
    # and enable below:
    # validates :reference, :uniqueness => { case_sensitive: false }

    has_many :prop_photos, -> { order 'sort_order asc' }
    has_many :features

    scope :for_rent, -> () { where('for_rent_short_term OR for_rent_long_term') }
    # couldn't do above if for_rent_short_term was a flatshihtzu boolean
    scope :for_sale, -> () { where for_sale: true }
    scope :visible, -> () { where visible: true }

    scope :in_zone, ->(key) { where zone_key: key }
    scope :in_locality, ->(key) { where locality_key: key }

    scope :property_type, ->(property_type) { where prop_type_key: property_type }
    scope :property_state, ->(property_state) { where prop_state_key: property_state }
    # scope :property_type, -> (property_type) { where property_type: property_type }
    # scope :property_state, -> (property_state) { where property_state: property_state }
    # below scopes used for searching
    scope :for_rent_price_from, ->(minimum_price) { where("price_rental_monthly_for_search_cents >= ?", minimum_price.to_s) }
    scope :for_rent_price_till, ->(maximum_price) { where("price_rental_monthly_for_search_cents <= ?", maximum_price.to_s) }
    scope :for_sale_price_from, ->(minimum_price) { where("price_sale_current_cents >= ?", minimum_price.to_s) }
    scope :for_sale_price_till, ->(maximum_price) { where("price_sale_current_cents <= ?", maximum_price.to_s) }
    scope :count_bathrooms, ->(min_count_bathrooms) { where("count_bathrooms >= ?", min_count_bathrooms.to_s) }
    scope :count_bedrooms, ->(min_count_bedrooms) { where("count_bedrooms >= ?", min_count_bedrooms.to_s) }
    # scope :starts_with, -> (name) { where("name like ?", "#{name}%")}
    # scope :pending, joins(:admin_request_status).where('admin_request_statuses.name = ?','Pending Approval')

    def has_garage
      count_garages && (count_garages > 0)
    end

    def for_rent
      for_rent_short_term || for_rent_long_term
    end

    def show_map
      if latitude.present? && longitude.present?
        !hide_map
      else
        false
      end
    end

    # Getter
    def get_extras
      Hash[features.map { |key, _value| [key.feature_key, true] }]
      # http://stackoverflow.com/questions/39567/what-is-the-best-way-to-convert-an-array-to-a-hash-in-ruby
      # returns something like {"terraza"=>true, "alarma"=>true, "gotele"=>true, "sueloMarmol"=>true}
      # - much easier to use on the client side admin page
    end

    # Setter- called by update_extras in properties controller
    # expects a hash with keys like "cl.casafactory.fieldLabels.extras.alarma"
    # each with a value of true or false
    def set_extras=(extras_json)
      return unless extras_json.class == Hash
      extras_json.keys.each do |feature_key|
        # TODO - create feature_key if its missing
        if extras_json[feature_key] == "true" || extras_json[feature_key] == true
          features.find_or_create_by( feature_key: feature_key)
        else
          features.where( feature_key: feature_key).delete_all
        end
      end
    end

    # below will return a translated (and sorted acc to translation)
    # list of extras for property
    def extras_for_display
      merged_extras = []
      get_extras.keys.each do |extra|
        # extras_field_key = "fieldLabels.extras.#{extra}"
        translated_option_key = I18n.t extra
        merged_extras.push translated_option_key

        # below check to ensure the field has not been deleted as
        # an available extra
        # quite an edge case - not entirely sure its worthwhile
        # if extras_field_configs[extras_field_key]
        #   translated_option_key = I18n.t extras_field_key
        #   merged_extras.push translated_option_key
        # end
      end
      merged_extras.sort{ |w1, w2| w1.casecmp(w2) }
      # above ensures sort is case insensitive
      # by default sort will add lowercased items to end of array
      # http://stackoverflow.com/questions/17799871/how-do-i-alphabetize-an-array-ignoring-case
      # return merged_extras.sort
    end

    def ordered_photo_url(number)
      # allows me to pick an individual image according to an order
      unless prop_photos.length >= number
        return "https://placeholdit.imgix.net/~text?txtsize=38&txt=&w=550&h=400&txttrack=0"
      end
      prop_photos[number - 1].image.url
    end

    def url_friendly_title
      # used in constructing seo friendly url
      if title && title.length > 2
        title.parameterize
      else
        "show"
      end
    end

    def contextual_show_path(rent_or_sale)
      unless rent_or_sale
        # where I am displaying items searched by ref number, won't know if its for sale or rent beforehand
        rent_or_sale = for_rent ? "for_rent" : "for_sale"
      end
      if rent_or_sale == "for_rent"
        return Pwb::Engine.routes.url_helpers.prop_show_for_rent_path(locale: I18n.locale, id: id, url_friendly_title: url_friendly_title)
      else
        return Pwb::Engine.routes.url_helpers.prop_show_for_sale_path(locale: I18n.locale, id: id, url_friendly_title: url_friendly_title)
      end
    end

    def contextual_price(rent_or_sale)
      unless rent_or_sale
        # where I am displaying items searched by ref number, won't know if its for sale or rent beforehand
        rent_or_sale = for_rent ? "for_rent" : "for_sale"
      end
      if rent_or_sale == "for_rent"
        # || rent_or_sale == "forRent"
        contextual_price = price_rental_monthly_for_search
        # contextual_price = self.rental_price
      else
        contextual_price = price_sale_current
      end
      contextual_price
      # .zero? ? nil : contextual_price.format(:no_cents => true)
    end

    # will return nil if price is 0
    def contextual_price_with_currency(rent_or_sale)
      contextual_price = self.contextual_price rent_or_sale

      if contextual_price.zero?
        return nil
      else
        return contextual_price.format(no_cents: true)
      end
      # return contextual_price.zero? ? nil : contextual_price.format(:no_cents => true)
    end

    def rental_price
      # deliberately checking short_term first
      # so that it overrides long_term price if both are set
      if for_rent_short_term
        rental_price = lowest_short_term_price || 0
      end
      unless rental_price && rental_price > 0
        rental_price = price_rental_monthly_current || 0
      end
      unless rental_price && rental_price > 0
        return nil
      end
      rental_price
    end

    def lowest_short_term_price
      prices_array = [price_rental_monthly_low_season, price_rental_monthly_standard_season, price_rental_monthly_high_season]
      # remove any prices that are 0:
      prices_array.reject! { |a| a.cents < 1 }
      prices_array.min
    end

    # def ano_constr=(ano_constr)
    #   self.year_construction = ano_constr
    # end

    # TODO: - replace below with db col
    # def area_unit
    #   return "sqft"
    #   # "sqmt"
    #   # "m<sup>2</sup>"
    # end
    # enum area_unit: [ :sqmt, :sqft ]
    # above method of declaring less flexible than below:
    enum area_unit: { sqmt: 0, sqft: 1 }

    before_save :set_rental_search_price
    after_create :set_defaults

    private

    def set_defaults
      # This is pretty ugly - need to create a service object
      # with DI as soon as I can:
      current_website = Website.unique_instance
      # default_currency = Website.last.present? ? Website.last.default_currency : nil
      if current_website.default_currency.present?
        self.currency = current_website.default_currency
        save
      end
      if current_website.default_area_unit.present?
        self.area_unit = current_website.default_area_unit
        save
      end
    end

    # called from before_save
    def set_rental_search_price
      # below for setting a value that I can use for searcing and ordering rental properties
      self.price_rental_monthly_for_search = rental_price
    end
  end
end
