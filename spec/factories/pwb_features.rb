# frozen_string_literal: true

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
FactoryBot.define do
  factory :pwb_feature, class: 'PwbTenant::Feature' do
    feature_key { 'feature.pool' }
  end
end
