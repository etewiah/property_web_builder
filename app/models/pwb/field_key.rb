module Pwb
  # A FieldKey records the translation key
  # that is used by a field such as propType
  class FieldKey < ApplicationRecord
    self.primary_key = :global_key

    scope :visible, -> () { where visible: true }
    # below 2 created so counter_cache works
    has_many :props_with_state, :class_name => :Prop, :foreign_key => "prop_state_key", :primary_key => :global_key

    has_many :props_with_type, :inverse_of => :prop_type, :class_name => :Prop, :foreign_key => "prop_type_key", :primary_key => :global_key
    # but above also allows:
    # FieldKey.find_by_global_key("propTypes.apartamento").props_with_type
    # though below might be better:
    # Prop.where(prop_type_key: "propTypes.apartamento")

    has_many :features, :inverse_of => :feature_field_key, :foreign_key => "feature_key", :primary_key => :global_key


    # below is used to get values to populate dropdowns in search forms
    def self.get_options_by_tag tag
      options = []
      translation_keys = FieldKey.where(tag: tag).visible.pluck("global_key")

      translation_keys.each do |option_key|
        option = OpenStruct.new
        option.value = option_key
        option.label = I18n.t option_key
        options.push option
      end
      return options.sort_by {|r| r.label.downcase }
    end


  end
end
