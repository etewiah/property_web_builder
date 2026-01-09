# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_saved_searches
# Database name: primary
#
#  id                 :bigint           not null, primary key
#  alert_frequency    :integer          default("none"), not null
#  email              :string           not null
#  email_verified     :boolean          default(FALSE), not null
#  enabled            :boolean          default(TRUE), not null
#  last_result_count  :integer          default(0)
#  last_run_at        :datetime
#  manage_token       :string           not null
#  name               :string
#  search_criteria    :jsonb            not null
#  seen_property_refs :jsonb            not null
#  unsubscribe_token  :string           not null
#  verification_token :string
#  verified_at        :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  website_id         :bigint           not null
#
# Indexes
#
#  index_pwb_saved_searches_on_email                 (email)
#  index_pwb_saved_searches_on_manage_token          (manage_token) UNIQUE
#  index_pwb_saved_searches_on_unsubscribe_token     (unsubscribe_token) UNIQUE
#  index_pwb_saved_searches_on_verification_token    (verification_token) UNIQUE
#  index_pwb_saved_searches_on_website_id            (website_id)
#  index_pwb_saved_searches_on_website_id_and_email  (website_id,email)
#  index_saved_searches_for_alerts                   (website_id,enabled,alert_frequency)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_saved_search, class: "Pwb::SavedSearch", aliases: [:saved_search] do
    association :website, factory: :pwb_website
    sequence(:email) { |n| "user#{n}@example.com" }
    search_criteria { { listing_type: "sale", location: "marbella" } }
    alert_frequency { :daily }
    enabled { true }
    email_verified { true }

    trait :weekly do
      alert_frequency { :weekly }
    end

    trait :disabled do
      enabled { false }
    end

    trait :unverified do
      email_verified { false }
      verification_token { SecureRandom.urlsafe_base64(32) }
    end

    trait :with_price_filter do
      search_criteria { { listing_type: "sale", min_price: 100_000, max_price: 500_000 } }
    end

    trait :with_bedroom_filter do
      search_criteria { { listing_type: "rental", min_bedrooms: 2, max_bedrooms: 4 } }
    end

    trait :complex_search do
      search_criteria do
        {
          listing_type: "sale",
          location: "marbella",
          min_price: 250_000,
          max_price: 750_000,
          min_bedrooms: 3,
          property_types: %w[villa apartment]
        }
      end
    end

    trait :with_seen_properties do
      seen_property_refs { %w[REF001 REF002 REF003] }
    end

    trait :ran_recently do
      last_run_at { 1.hour.ago }
      last_result_count { 5 }
    end

    trait :needs_daily_run do
      alert_frequency { :daily }
      last_run_at { 25.hours.ago }
    end

    trait :needs_weekly_run do
      alert_frequency { :weekly }
      last_run_at { 8.days.ago }
    end
  end
end
