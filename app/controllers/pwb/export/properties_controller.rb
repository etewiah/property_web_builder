module Pwb
  class Export::PropertiesController < ApplicationApiController
    puts "Pwb::Export::PropertiesController loaded"
    protect_from_forgery with: :null_session
    def all
      puts "Export::PropertiesController#all reached"
      properties = Pwb::Prop.all
      # where(:id,)
      # @header_cols = ["Id", "Title in English", "Title in Spanish",
      #                 "Description in English", "Description in Spanish",
      #                 "Sale price", "Rental Price",
      #                 "Number of bedrooms", "Number of bathrooms", "Number of toilets", "Number of garages",
      #                 "Street Address", "Street Number", "Postal Code",
      #                 "City", "Country", "Longitude", "Latitude"]
      @prop_fields = %i[id title_en title_es
                        description_en description_es
                        price_sale_current_cents price_rental_monthly_current_cents
                        count_bedrooms count_bathrooms count_toilets count_garages
                        street_address street_number postal_code
                        city country longitude latitude]
      @props_array = []
      properties.each do |prop|
        prop_field_values = []
        @prop_fields.each do |field|
          # for each of the prop_fields
          # get its value for the current prop
          prop_field_values << (prop.send field)
          # prop[field] would work instead of "prop.send field" in most
          # cases but not for title_es and associated fields
        end
        @props_array << prop_field_values
      end
      headers['Content-Disposition'] = "attachment; filename=\"pwb-properties.csv\""
      headers['Content-Type'] ||= 'text/csv'
      begin
        render "all.csv"
      rescue => e
        puts "Export error: #{e.message}"
        puts e.backtrace
        raise e
      end
    end
  end
end
