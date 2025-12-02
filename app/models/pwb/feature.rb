module Pwb
  class Feature < ApplicationRecord
    belongs_to :prop, optional: true

    belongs_to :feature_field_key, optional: true, class_name: "Pwb::FieldKey", foreign_key: :feature_key, inverse_of: :features
    # above allows:
    # Property.first.features.count and
    # FieldKey.last.properties_count but most importantly
    # FieldKey.where(tag: "extras").where('properties_count > ?', 0)
    # above will get only extras that are in use - usefull for an improved searchbox

    # below should allow me to count how many properties have a given extra/feature
    # by setting properties_count on field_key
    # , :counter_cache => "properties_count"
    # counter_culture :feature_field_key, :column_name => "properties_count"
  end
end
