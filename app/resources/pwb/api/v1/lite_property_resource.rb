module Pwb
  # class LitepropResource < JSONAPI::Resource
  class Api::V1::LitePropertyResource < JSONAPI::Resource
    model_name 'Pwb::Prop'
    # model_hint model: Pwb::Prop, resource: :lite_properties
    attributes :year_construction
    # attributes :ano_constr, :street_address, :street_number, :postal_code
    # attributes :locality_title, :zone_title, :city, :region, :country, :longitude, :latitude


    attributes :count_bedrooms, :count_bathrooms, :count_toilets, :count_garages
    attributes :constructed_area, :plot_area

    # attributes :price_sale_current_cents, :price_sale_original_cents, :price_rental_monthly_current_cents, :price_rental_monthly_original_cents
    # attributes :price_rental_monthly_low_season_cents, :price_rental_monthly_high_season_cents, :price_rental_monthly_standard_season_cents


    # attributes :hipoteca, :llaves, :llaves_situacion, :escrituras, :ref_catastral
    # attributes :url_eficiencia, :eficiencia_energia, :observaciones_venta

    attributes :property_type_key
    attributes :num_habitaciones, :num_banos
    # , :num_aseos

    # below needed till I rewrite client side to use new cols
    def property_type_key
      return @model.prop_type_key
    end
    def num_habitaciones
      return @model.count_bedrooms
    end
    def num_banos
      return @model.count_bathrooms
    end


    # attributes :for_sale, :for_rent_short_term, :for_rent_long_term, :obscure_map, :hide_map
    # attributes :yaencontre, :pisoscom, :idealista,
    attributes :visible, :highlighted, :reference

    filters :visible
  end
end
