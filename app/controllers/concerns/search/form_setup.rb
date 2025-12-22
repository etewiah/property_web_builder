# frozen_string_literal: true

module Search
  # Extracts search form setup logic from SearchController
  # Handles setting up select options and form defaults
  module FormSetup
    extend ActiveSupport::Concern

    private

    # Set up common search form inputs (property types, states, features, amenities)
    def set_common_search_inputs
      @property_types = Pwb::FieldKey.get_options_by_tag("property-types")
      @property_types.unshift OpenStruct.new(value: "", label: "")
      @property_states = Pwb::FieldKey.get_options_by_tag("property-states")
      @property_features = Pwb::FieldKey.get_options_by_tag("property-features")
      @property_amenities = Pwb::FieldKey.get_options_by_tag("property-amenities")
    end

    # Set up localized texts for select picker UI component
    def set_select_picker_texts
      @select_picker_texts = {
        noneSelectedText: I18n.t("selectpicker.noneSelectedText"),
        noneResultsText: I18n.t("selectpicker.noneResultsText"),
        countSelectedText: I18n.t("selectpicker.countSelectedText")
      }.to_json
    end

    # Get the header image URL from landing page content
    def header_image_url
      lc_photo = Pwb::ContentPhoto.find_by_block_key("landing_img")
      @header_image_url = lc_photo.present? ? lc_photo.optimized_image_url : nil
    end
  end
end
