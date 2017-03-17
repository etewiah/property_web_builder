module Pwb
  class ImportProperties
    attr_accessor :csv_file

    def initialize(csv_file)
      self.csv_file = csv_file
    end

    def import_csv
      imported_properties = []
      CSV.foreach(csv_file.path, headers: true) do |row|
        # TODO - more robust check for valid cols
        if row.to_hash["title_en"].present? 
          # && row.to_hash["key"].present?
          new_prop = Prop.create! row.to_hash.except("id")
          imported_properties.push new_prop
        end
      end
      imported_properties
    end

  end
end
