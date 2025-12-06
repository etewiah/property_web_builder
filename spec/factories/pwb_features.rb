FactoryBot.define do
  factory :pwb_feature, class: 'PwbTenant::Feature' do
    feature_key { 'feature.pool' }
  end
end
