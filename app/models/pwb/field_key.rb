module Pwb
  # A FieldKey records the translation key
  # that is used by a field such as propType
  class FieldKey < ApplicationRecord
    self.primary_key = :global_key

    # Associations
    belongs_to :website, optional: true, foreign_key: :pwb_website_id, class_name: 'Pwb::Website'

    # Scopes
    scope :visible, -> { where visible: true }
    scope :for_website, ->(website_id) { where(pwb_website_id: website_id) }
    scope :by_tag, ->(tag) { where(tag: tag) }
    
    # Validations
    validates :global_key, presence: true, uniqueness: { scope: :pwb_website_id }
    validates :tag, presence: true
    # Legacy Prop associations - kept for backwards compatibility
    has_many :props_with_state, class_name: "Pwb::Prop", foreign_key: "prop_state_key", primary_key: :global_key
    has_many :props_with_type, inverse_of: :prop_type, class_name: "Pwb::Prop", foreign_key: "prop_type_key", primary_key: :global_key
    # Usage: FieldKey.find_by_global_key("propTypes.apartamento").props_with_type
    # or: Prop.where(prop_type_key: "propTypes.apartamento")

    # New RealtyAsset associations
    has_many :realty_assets_with_state, class_name: "Pwb::RealtyAsset", foreign_key: "prop_state_key", primary_key: :global_key
    has_many :realty_assets_with_type, class_name: "Pwb::RealtyAsset", foreign_key: "prop_type_key", primary_key: :global_key

    has_many :features, inverse_of: :feature_field_key, foreign_key: "feature_key", primary_key: :global_key

    # below is used to get values to populate dropdowns in search forms
    def self.get_options_by_tag(tag)
      options = []
      translation_keys = FieldKey.where(tag: tag).visible.pluck("global_key")

      translation_keys.each do |option_key|
        option = OpenStruct.new
        option.value = option_key
        option.label = I18n.t option_key
        options.push option
      end
      options.sort_by { |r| r.label.downcase }
    end
  end
end
