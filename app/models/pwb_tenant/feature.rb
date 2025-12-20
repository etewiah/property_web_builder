# frozen_string_literal: true

module PwbTenant
  # Tenant-scoped version of Feature.
  # Inherits all functionality from Pwb::Feature.
  #
  # Note: Feature doesn't have a website_id column - it inherits tenancy through
  # its parent Prop/RealtyAsset. No acts_as_tenant needed here, tenant scoping
  # happens through the parent association.
  #
  # Use this in web requests where tenant isolation is required.
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
  class Feature < Pwb::Feature
    # No acts_as_tenant since Feature doesn't have website_id
    # Tenant scoping is handled through the parent RealtyAsset/Prop
  end
end
