# frozen_string_literal: true

module Pwb
  # FieldKey records translation keys used by fields like propType, propState, features.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::FieldKey for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  # The table uses `pwb_website_id` as the foreign key column (not `website_id`).
  #
  class FieldKey < ApplicationRecord
    self.table_name = 'pwb_field_keys'
    self.primary_key = :global_key

    belongs_to :website, class_name: 'Pwb::Website', foreign_key: 'pwb_website_id', optional: true

    # Scopes
    scope :visible, -> { where(visible: true) }
    scope :by_tag, ->(tag) { where(tag: tag) }
    scope :ordered, -> { order(:sort_order, :created_at) }

    # Validations
    # Note: uniqueness is scoped by pwb_website_id (the actual column name)
    validates :global_key, presence: true, uniqueness: { scope: :pwb_website_id }
    validates :tag, presence: true

    # RealtyAsset associations
    has_many :realty_assets_with_state, class_name: 'Pwb::RealtyAsset', foreign_key: 'prop_state_key', primary_key: :global_key
    has_many :realty_assets_with_type, class_name: 'Pwb::RealtyAsset', foreign_key: 'prop_type_key', primary_key: :global_key

    has_many :features, class_name: 'Pwb::Feature', foreign_key: 'feature_key', primary_key: :global_key

    # Get values to populate dropdowns in search forms.
    # Returns an array of OpenStruct objects with :value and :label.
    #
    # Note: This method does NOT automatically scope by tenant. When called from
    # a web context, use PwbTenant::FieldKey.get_options_by_tag instead, or
    # ensure you're calling within an ActsAsTenant.with_tenant block.
    #
    # @param tag [String] The tag to filter by (e.g., 'property-types')
    # @return [Array<OpenStruct>] Options sorted by sort_order, then created_at
    #
    def self.get_options_by_tag(tag)
      where(tag: tag)
        .visible
        .ordered
        .map do |field_key|
          OpenStruct.new(
            value: field_key.global_key,
            label: I18n.t(field_key.global_key, default: field_key.global_key),
            sort_order: field_key.sort_order
          )
        end
    end
  end
end
