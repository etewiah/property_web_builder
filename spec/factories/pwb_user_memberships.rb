# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_user_memberships
# Database name: primary
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  role       :string           default("member"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
#  website_id :bigint           not null
#
# Indexes
#
#  index_pwb_user_memberships_on_user_id       (user_id)
#  index_pwb_user_memberships_on_website_id    (website_id)
#  index_user_memberships_on_user_and_website  (user_id,website_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_user_membership, class: 'Pwb::UserMembership' do
    association :user, factory: :pwb_user
    association :website, factory: :pwb_website
    role { 'member' }
    active { true }

    trait :owner do
      role { 'owner' }
    end

    trait :admin do
      role { 'admin' }
    end

    trait :member do
      role { 'member' }
    end

    trait :viewer do
      role { 'viewer' }
    end

    trait :inactive do
      active { false }
    end
  end
end
