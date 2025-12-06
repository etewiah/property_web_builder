# frozen_string_literal: true

module PwbTenant
  # A FieldKey records the translation key used by fields like propType
  # Tenant-scoped version for multi-tenancy
  class FieldKey < ApplicationRecord
    self.primary_key = :global_key

    # Scopes
    scope :visible, -> { where(visible: true) }
    scope :by_tag, ->(tag) { where(tag: tag) }

    # Validations
    validates :global_key, presence: true, uniqueness: { scope: :website_id }
    validates :tag, presence: true

    # Legacy Prop associations
    has_many :props_with_state, class_name: 'PwbTenant::Prop', foreign_key: 'prop_state_key', primary_key: :global_key
    has_many :props_with_type, class_name: 'PwbTenant::Prop', foreign_key: 'prop_type_key', primary_key: :global_key

    # RealtyAsset associations
    has_many :realty_assets_with_state, class_name: 'PwbTenant::RealtyAsset', foreign_key: 'prop_state_key', primary_key: :global_key
    has_many :realty_assets_with_type, class_name: 'PwbTenant::RealtyAsset', foreign_key: 'prop_type_key', primary_key: :global_key

    has_many :features, class_name: 'PwbTenant::Feature', foreign_key: 'feature_key', primary_key: :global_key

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
