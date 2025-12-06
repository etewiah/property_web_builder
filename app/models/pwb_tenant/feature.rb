# frozen_string_literal: true

module PwbTenant
  # Feature doesn't have a website_id column - it inherits tenancy through
  # its parent Prop/RealtyAsset. Using ActiveRecord::Base directly.
  class Feature < ActiveRecord::Base
    self.table_name = 'pwb_features'

    # Both associations supported for backwards compatibility
    belongs_to :prop, optional: true, class_name: 'PwbTenant::Prop'
    belongs_to :realty_asset, optional: true, class_name: 'PwbTenant::RealtyAsset'

    belongs_to :feature_field_key, optional: true, class_name: 'PwbTenant::FieldKey',
                                   foreign_key: :feature_key, primary_key: :global_key
  end
end
