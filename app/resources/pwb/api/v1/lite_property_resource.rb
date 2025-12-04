module Pwb
  # Lite version of PropertyResource with fewer attributes for faster loading
  class Api::V1::LitePropertyResource < JSONAPI::Resource
    # Use Pwb::Property (materialized view) for read operations
    model_name 'Pwb::Property'

    attributes :year_construction
    attributes :prop_type_key, :prop_state_key, :prop_origin_key
    attributes :count_bedrooms, :count_bathrooms, :count_toilets, :count_garages
    attributes :constructed_area, :plot_area

    # Legacy attribute names for backwards compatibility
    attributes :property_type_key
    attributes :num_habitaciones, :num_banos

    def property_type_key
      @model.prop_type_key
    end

    def num_habitaciones
      @model.count_bedrooms
    end

    def num_banos
      @model.count_bathrooms
    end

    attributes :visible, :highlighted, :reference

    filters :visible

    # Scope properties to current website for multi-tenancy
    def self.records(options = {})
      current_website = Pwb::Current.website
      if current_website
        Pwb::Property.where(website_id: current_website.id)
      else
        Pwb::Property.none
      end
    end
  end
end
