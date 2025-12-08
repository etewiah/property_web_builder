FactoryBot.define do
  factory :pwb_authorization, class: 'Pwb::Authorization' do
    association :user, factory: :pwb_user
    provider { "google" }
    uid { SecureRandom.uuid }
  end
end
