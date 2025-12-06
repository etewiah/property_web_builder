# frozen_string_literal: true

module Pwb
  # FieldKey records translation keys used by fields like propType, propState, features.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::FieldKey for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class FieldKey < ApplicationRecord
    self.table_name = 'pwb_field_keys'
    self.primary_key = :global_key

    belongs_to :website, class_name: 'Pwb::Website', foreign_key: 'pwb_website_id', optional: true

    # Scopes
    scope :visible, -> { where(visible: true) }
    scope :by_tag, ->(tag) { where(tag: tag) }

    # Validations
    validates :global_key, presence: true, uniqueness: { scope: :website_id }
    validates :tag, presence: true

    # Legacy Prop associations
    has_many :props_with_state, class_name: 'Pwb::Prop', foreign_key: 'prop_state_key', primary_key: :global_key
    has_many :props_with_type, class_name: 'Pwb::Prop', foreign_key: 'prop_type_key', primary_key: :global_key

    # RealtyAsset associations
    has_many :realty_assets_with_state, class_name: 'Pwb::RealtyAsset', foreign_key: 'prop_state_key', primary_key: :global_key
    has_many :realty_assets_with_type, class_name: 'Pwb::RealtyAsset', foreign_key: 'prop_type_key', primary_key: :global_key

    has_many :features, class_name: 'Pwb::Feature', foreign_key: 'feature_key', primary_key: :global_key

    # Get values to populate dropdowns in search forms
    def self.get_options_by_tag(tag)
      options = []
      translation_keys = where(tag: tag).visible.pluck(:global_key)

      translation_keys.each do |option_key|
        option = OpenStruct.new
        option.value = option_key
        option.label = I18n.t(option_key)
        options.push(option)
      end
      options.sort_by { |r| r.label.downcase }
    end
  end
end
