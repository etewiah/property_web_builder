# frozen_string_literal: true

FactoryBot.define do
  factory :pwb_saved_property, class: "Pwb::SavedProperty", aliases: [:saved_property] do
    association :website, factory: :pwb_website
    sequence(:email) { |n| "user#{n}@example.com" }
    provider { "resales_online" }
    sequence(:external_reference) { |n| "REF#{n.to_s.rjust(6, '0')}" }
    property_data do
      {
        title: "Beautiful Villa in Marbella",
        price: 450_000,
        currency: "EUR",
        bedrooms: 3,
        bathrooms: 2,
        city: "Marbella",
        listing_type: "sale",
        images: ["https://example.com/image1.jpg", "https://example.com/image2.jpg"]
      }
    end
    original_price_cents { 450_000 }
    current_price_cents { 450_000 }

    trait :rental do
      property_data do
        {
          title: "Modern Apartment for Rent",
          price: 1500,
          currency: "EUR",
          bedrooms: 2,
          bathrooms: 1,
          city: "Malaga",
          listing_type: "rental",
          images: ["https://example.com/apt1.jpg"]
        }
      end
      original_price_cents { 1500 }
      current_price_cents { 1500 }
    end

    trait :with_notes do
      notes { "Great location, close to beach. Schedule viewing next week." }
    end

    trait :price_reduced do
      original_price_cents { 500_000 }
      current_price_cents { 450_000 }
      price_changed_at { 2.days.ago }
    end

    trait :price_increased do
      original_price_cents { 400_000 }
      current_price_cents { 450_000 }
      price_changed_at { 1.day.ago }
    end

    trait :without_images do
      property_data do
        {
          title: "Property Without Images",
          price: 200_000,
          currency: "EUR",
          bedrooms: 2,
          bathrooms: 1,
          city: "Estepona",
          listing_type: "sale",
          images: []
        }
      end
    end
  end
end
