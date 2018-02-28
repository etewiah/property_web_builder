module Pwb
  class DisplayPropertiesQuery
    # TODO: make better use of this class
    attr_reader :relation

    def initialize(relation = Prop.all)
      @relation = relation
    end

    def for_sale
      result = relation.public_send("for_sale").visible.order('highlighted DESC').limit 9
      as_json_for_fe(result)
    end

    def for_rent
      result = relation.public_send("for_rent").visible.order('highlighted DESC').limit 9
      as_json_for_fe(result)
    end

    private

    def as_json_for_fe(result, options = nil)
      result.as_json(
        {only: [
           "id", "reference", "year_construction", "count_bedrooms", "count_bathrooms", "count_toilets", "count_garages",
           "plot_area", "constructed_area", 
           # "energy_rating", "energy_performance", "flags", "furnished", "sold", "reserved",
           "highlighted", "archived", "visible", "for_rent_short_term", "for_rent_long_term", "for_sale",
           "hide_map", "obscure_map",
            # "portals_enabled", "deleted_at", "active_from", "available_to_rent_from",
           # "available_to_rent_till",
           "price_sale_current_cents", "price_sale_current_currency",
           "price_sale_original_cents",
           "price_sale_original_currency",
           "price_rental_monthly_current_cents", "price_rental_monthly_current_currency",
           "price_rental_monthly_original_cents", "price_rental_monthly_original_currency",
           "price_rental_monthly_low_season_cents", "price_rental_monthly_low_season_currency",
           "price_rental_monthly_high_season_cents", "price_rental_monthly_high_season_currency",
           "price_rental_monthly_standard_season_cents", "price_rental_monthly_standard_season_currency",
           # "commission_cents",
           # "commission_currency", "service_charge_yearly_cents", "service_charge_yearly_currency",
           "price_rental_monthly_for_search_cents", "price_rental_monthly_for_search_currency", "currency", "prop_origin_key",
           "prop_state_key", "prop_type_key", "street_number", "street_name", "street_address", "postal_code", "province",
           "city", "region", "country", "latitude", "longitude", "area_unit",
           "title"
         ],
         methods: :primary_image_url}.merge(options || {}))
    end
  end
end
