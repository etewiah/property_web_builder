module Pwb
  class DisplayPropertiesQuery
    # TODO: make better use of this class
    # TODO: add tests
    attr_reader :relation
    attr_reader :filtering_params
    attr_reader :currency_string

    # having the first param as a relation means
    # I can chain queries
    # def initialize(relation: Prop.all, search_params: [])
    def initialize(search_params: {})
      if search_params["op"] == "rent"
        relation = Prop.visible.for_rent
      else
        relation = Prop.visible.for_sale
      end
      @currency_string = "usd"

      filtering_params = {}

      # below is a mapping of the keys I use as query string keys
      # on client front end to the internal filters on prop.rb model
      params_mapping = {
        type: "property_type_without_prefix",
        state: "property_state_without_prefix",
        bedrooms_min: "count_bedrooms_from",
        bedrooms_max: "count_bedrooms_till",
        bathrooms_min: "count_bathrooms_from",
        bathrooms_max: "count_bathrooms_till",
        price_min: "for_sale_price_from",
        price_max: "for_sale_price_till",
      }

      if search_params["op"] == "rent"
        params_mapping[:price_min] = "for_rent_price_from"
        params_mapping[:price_max] = "for_rent_price_till"
      end

      params_mapping.each do |mapping_key, mapping_value|
        # 
        if search_params[mapping_key]
          filtering_params[mapping_value] = search_params[mapping_key]
        end
      end
      # search_params.each do |search_param_key, search_param_value|
      #   if search_param_key == "price_from"
      #     filtering_params["for_sale_price_from"] = search_param_value
      #   end
      # end
      @relation = relation
      @filtering_params = filtering_params
    end

    def for_sale
      result = Prop.visible.for_sale.order('highlighted DESC').limit 9
      as_json_for_fe(result)
    end

    def for_rent
      result = Prop.visible.for_rent.order('highlighted DESC').limit 9
      as_json_for_fe(result)
    end

    def from_params
      result = apply_search_filter(filtering_params)
      as_json_for_fe(result)
    end

    private

    def apply_search_filter(search_filtering_params)
      result = relation
      # relation is not available below if I try
      # to access it directly without above
      search_filtering_params.each do |key, value|
        empty_values = ["propertyTypes."]
        if (empty_values.include? value) || value.empty?
          next
        end
        price_fields = ["for_sale_price_from", "for_sale_price_till", "for_rent_price_from", "for_rent_price_till"]
        if price_fields.include? key
          # TODO handle situations where invalid value is passed here
          currency = Money::Currency.find currency_string
          # needed as some currencies like Chilean peso
          # don't have the cents field multiplied by 100
          value = value.gsub(/\D/, '').to_i * currency.subunit_to_unit
          # @properties = @properties.public_send(key, value) if value.present?
        end
        result = result.public_send(key, value) if value.present?
      end
      result
    end

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
