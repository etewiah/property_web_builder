# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_authorizations
# Database name: primary
#
#  id         :bigint           not null, primary key
#  provider   :string
#  uid        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_pwb_authorizations_on_user_id  (user_id)
#
FactoryBot.define do
  factory :pwb_authorization, class: 'Pwb::Authorization' do
    association :user, factory: :pwb_user
    provider { "google" }
    uid { SecureRandom.uuid }
  end
end
