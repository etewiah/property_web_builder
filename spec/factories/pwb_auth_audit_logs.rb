# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_auth_audit_logs
#
#  id             :bigint           not null, primary key
#  email          :string
#  event_type     :string           not null
#  failure_reason :string
#  ip_address     :string
#  metadata       :jsonb
#  provider       :string
#  request_path   :string
#  user_agent     :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :bigint
#  website_id     :bigint
#
FactoryBot.define do
  factory :pwb_auth_audit_log, class: 'Pwb::AuthAuditLog' do
    association :website, factory: :pwb_website
    association :user, factory: :pwb_user
    sequence(:email) { |n| "user#{n}@example.com" }
    event_type { 'login_success' }
    ip_address { '192.168.1.1' }
    user_agent { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' }
    request_path { '/users/sign_in' }

    trait :login_success do
      event_type { 'login_success' }
    end

    trait :login_failure do
      event_type { 'login_failure' }
      failure_reason { 'Invalid password' }
    end

    trait :logout do
      event_type { 'logout' }
    end

    trait :oauth_success do
      event_type { 'oauth_success' }
      provider { 'google_oauth2' }
    end

    trait :oauth_failure do
      event_type { 'oauth_failure' }
      provider { 'google_oauth2' }
      failure_reason { 'Account not found' }
    end

    trait :password_reset_request do
      event_type { 'password_reset_request' }
    end

    trait :password_reset_success do
      event_type { 'password_reset_success' }
    end

    trait :account_locked do
      event_type { 'account_locked' }
      failure_reason { 'Locked after 5 failed attempts' }
    end

    trait :account_unlocked do
      event_type { 'account_unlocked' }
      metadata { { unlock_method: 'email' } }
    end

    trait :session_timeout do
      event_type { 'session_timeout' }
    end

    trait :registration do
      event_type { 'registration' }
    end

    trait :today do
      created_at { Time.current }
    end

    trait :yesterday do
      created_at { 1.day.ago }
    end

    trait :last_week do
      created_at { 1.week.ago }
    end

    trait :without_user do
      user { nil }
    end
  end
end
