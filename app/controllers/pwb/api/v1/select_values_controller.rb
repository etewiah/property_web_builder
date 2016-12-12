require_dependency "pwb/application_controller"

module Pwb
  class Api::V1::SelectValuesController < ApplicationApiController
    # respond_to :json

    # protect_from_forgery with: :null_session

    # will return a hash of arrays with the i18n keys that are relevant
    # for each dropdown group of labels
    def by_field_names
      field_names_string = params["field_names"] || ""
      # "property-origins, property-types, property-states, provinces"

      # below used to populate dropdown list to select
      # client for property
      # if field_names_string == "clients"
      #   clients_array = [{:value => "", :label => ""}]
      #   # TODO - have some filter for below
      #   clients = Client.all
      #   clients.each do |client|
      #     clients_array.push( {:value => client.id,
      #                          :label => client.full_name})
      #   end
      #   return render json: { clients: clients_array}
      # end


      field_names_array = field_names_string.split(",")
      # above might return something like
      # ["extras"] or
      # ["provinces","property-states"]
      select_values = {}
      # a field_name_id identifies a dropdown field for
      # which I need a list of translation keys
      # for example extras
      field_names_array.each do |field_name_id|
        # a field_name_id might be:
        # extras
        field_name_id = field_name_id.strip

        # gets a list of translation keys for a given field:
        translation_keys = FieldKey.where(tag: field_name_id).visible.pluck("global_key")
        select_values[field_name_id] = translation_keys
      end
      return render json: select_values
    end

  end
end

