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
# == Schema Information
#
# Table name: pwb_features
#
#  id              :integer          not null, primary key
#  feature_key     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  prop_id         :integer
#  realty_asset_id :uuid
#
# Indexes
#
#  index_pwb_features_on_feature_key                      (feature_key)
#  index_pwb_features_on_realty_asset_id                  (realty_asset_id)
#  index_pwb_features_on_realty_asset_id_and_feature_key  (realty_asset_id,feature_key)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#
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
