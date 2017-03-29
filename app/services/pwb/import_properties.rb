module Pwb
  class ImportProperties
    attr_accessor :csv_file

    def initialize(csv_file)
      self.csv_file = csv_file
    end

    def import_csv
      imported_properties = []
      csv_options = { headers: true}
      CSV.foreach(csv_file.path, csv_options) do |row|
        # TODO - more robust check for valid cols
        if row.to_hash["title_en"].present?
          # && row.to_hash["key"].present?
          new_prop = Prop.create! row.to_hash.except("id")
          imported_properties.push new_prop
        end
      end
      imported_properties
    end

    def import_mls_tsv
      parsed_properties = []
      csv_options = { headers: true, col_sep: "\t" }
      CSV.foreach(csv_file.path, csv_options) do |row|
        mapped_property = ImportMapper.new("mls_csv_jon").map_property(row)
        parsed_properties.push mapped_property
        # reference = row.to_hash["ML Number"]
        # byebug
        # if reference.present? && !Pwb::Prop.exists?(reference: reference)
        #   mappings = {
        #     "ML Number" => "reference", "Street Name" => "street_name",
        #     "Latitude" => "latitude", "Longitude" => "longitude",
        #     "List Price" => "price_sale_current",
        #     "Age" => "year_construction", "Street Number 1" => "street_number",
        #     "City Name" => "city", "State" => "province"
        #   }
        #   pwb_prop_hash = row.to_hash.map {|k, v| [mappings[k], v] }.to_h

        #   # byebug

        #   new_prop = Prop.create! pwb_prop_hash.except(nil)
        #   parsed_properties.push new_prop
        # end
      end
      return parsed_properties
    end


  end
end
