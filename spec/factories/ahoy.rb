# frozen_string_literal: true

FactoryBot.define do
  factory :ahoy_visit, class: 'Ahoy::Visit' do
    association :website, factory: :website
    visit_token { SecureRandom.uuid }
    visitor_token { SecureRandom.uuid }
    started_at { Time.current }
    
    trait :with_user do
      association :user, factory: :user
    end

    trait :from_google do
      referrer { 'https://www.google.com/search?q=property' }
      referring_domain { 'google.com' }
    end

    trait :from_facebook do
      referrer { 'https://www.facebook.com/' }
      referring_domain { 'facebook.com' }
    end

    trait :direct do
      referrer { nil }
      referring_domain { nil }
    end

    trait :mobile do
      device_type { 'Mobile' }
      browser { 'Safari' }
      os { 'iOS' }
    end

    trait :desktop do
      device_type { 'Desktop' }
      browser { 'Chrome' }
      os { 'Windows' }
    end

    trait :with_location do
      country { 'United States' }
      region { 'California' }
      city { 'San Francisco' }
    end

    trait :with_utm do
      utm_source { 'google' }
      utm_medium { 'cpc' }
      utm_campaign { 'spring_sale' }
    end
  end

  factory :ahoy_event, class: 'Ahoy::Event' do
    association :website, factory: :website
    association :visit, factory: :ahoy_visit
    name { 'page_viewed' }
    properties { { path: '/', page_type: 'home' } }
    time { Time.current }

    trait :page_view do
      name { 'page_viewed' }
      properties { { path: '/', page_type: 'home' } }
    end

    trait :property_view do
      name { 'property_viewed' }
      properties { { property_id: rand(1..1000), property_type: 'sale' } }
    end

    trait :inquiry do
      name { 'inquiry_submitted' }
      properties { { property_id: rand(1..1000), source: 'contact_form' } }
    end

    trait :search do
      name { 'property_searched' }
      properties { { query: 'apartment', results_count: rand(1..50) } }
    end

    trait :contact_form_opened do
      name { 'contact_form_opened' }
      properties { { property_id: rand(1..1000) } }
    end

    trait :gallery_viewed do
      name { 'gallery_viewed' }
      properties { { property_id: rand(1..1000) } }
    end
  end
end
