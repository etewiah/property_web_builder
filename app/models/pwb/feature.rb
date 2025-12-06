# frozen_string_literal: true

module Pwb
  # Feature represents a property feature (e.g., pool, garden, garage).
  # Features are linked to properties via realty_asset_id.
  #
  # Note: This model doesn't have a website_id column - it inherits tenancy
  # through its parent Prop/RealtyAsset. Using ActiveRecord::Base directly.
  #
  # Use PwbTenant::Feature for tenant-scoped queries in web requests.
  # Use Pwb::Feature for console work or cross-tenant operations.
  #
  class Feature < ActiveRecord::Base
    self.table_name = 'pwb_features'

    # Both associations supported for backwards compatibility
    belongs_to :prop, optional: true, class_name: 'Pwb::Prop'
    belongs_to :realty_asset, optional: true, class_name: 'Pwb::RealtyAsset'

    belongs_to :feature_field_key, optional: true, class_name: 'Pwb::FieldKey',
                                   foreign_key: :feature_key, primary_key: :global_key
  end
end
