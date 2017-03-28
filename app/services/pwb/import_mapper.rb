require 'Rets'
module Pwb
  class ImportMapper
    attr_accessor :mapping_data

    def initialize(mapping_data)
      self.mapping_data = mapping_data
    end

    def map_property mls_property
      mappings = {
        "ListingKey" => "reference"
      }
      # mappings = {
      #   "ML Number" => "reference", "Street Name" => "street_name",
      #   "Latitude" => "latitude", "Longitude" => "longitude",
      #   "List Price" => "price_sale_current",
      #   "Age" => "year_construction", "Street Number 1" => "street_number",
      #   "City Name" => "city", "State" => "province"
      # }
      mapped_property = mls_property.to_hash.map {|k, v| [mappings[k], v] }.to_h

      return mapped_property.except(nil)
    end


  end
end
