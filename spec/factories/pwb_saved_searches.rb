# frozen_string_literal: true

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
          property_types: ["villa", "apartment"]
        }
      end
    end

    trait :with_seen_properties do
      seen_property_refs { ["REF001", "REF002", "REF003"] }
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
