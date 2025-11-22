module ApiPublic
  module V1
    class SelectValuesController < BaseController
      # Returns select options for dropdowns like property types
      def index
        field_names_string = params["field_names"] || ""
        field_names_array = field_names_string.split(",")
        
        select_values = {}
        field_names_array.each do |field_name_id|
          field_name_id = field_name_id.strip
          # Get options from FieldKeys
          options = Pwb::FieldKey.get_options_by_tag(field_name_id)
          # Format as simple array of {value, label} objects
          select_values[field_name_id] = options.map { |opt| { value: opt.value, label: opt.label } }
        end
        
        render json: select_values
      end
    end
  end
end
