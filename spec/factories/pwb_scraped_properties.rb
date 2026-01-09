# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_scraped_properties
# Database name: primary
#
#  id                    :uuid             not null, primary key
#  connector_used        :string
#  extracted_data        :jsonb
#  extracted_images      :jsonb
#  import_status         :string           default("pending")
#  imported_at           :datetime
#  raw_html              :text
#  scrape_error_message  :string
#  scrape_method         :string
#  scrape_successful     :boolean          default(FALSE)
#  script_json           :text
#  source_host           :string
#  source_portal         :string
#  source_url            :string           not null
#  source_url_normalized :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  realty_asset_id       :uuid
#  website_id            :bigint           not null
#
# Indexes
#
#  index_pwb_scraped_properties_on_import_status               (import_status)
#  index_pwb_scraped_properties_on_realty_asset_id             (realty_asset_id)
#  index_pwb_scraped_properties_on_source_url_normalized       (source_url_normalized)
#  index_pwb_scraped_properties_on_website_id                  (website_id)
#  index_pwb_scraped_properties_on_website_id_and_source_host  (website_id,source_host)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_scraped_property, class: "Pwb::ScrapedProperty" do
    association :website, factory: :pwb_website
    sequence(:source_url) { |n| "https://www.rightmove.co.uk/properties/#{100_000 + n}" }
    import_status { "pending" }
    scrape_successful { false }

    trait :with_successful_scrape do
      scrape_successful { true }
      scrape_method { "auto" }
      connector_used { "http" }
      import_status { "previewing" }
      raw_html { "<html><head><title>Test Property</title></head><body>Content</body></html>" }
      extracted_data do
        {
          "asset_data" => {
            "count_bedrooms" => 3,
            "count_bathrooms" => 2,
            "city" => "London",
            "postal_code" => "SW1A 1AA",
            "country" => "UK",
            "prop_type_key" => "apartment",
            "constructed_area" => 120
          },
          "listing_data" => {
            "title" => "Beautiful 3 Bedroom Apartment",
            "description" => "A stunning property in the heart of London.",
            "price_sale_current" => 450_000,
            "currency" => "GBP"
          }
        }
      end
      extracted_images { ["https://example.com/image1.jpg", "https://example.com/image2.jpg"] }
    end

    trait :with_manual_html do
      scrape_successful { true }
      scrape_method { "manual_html" }
      connector_used { nil }
      import_status { "previewing" }
      raw_html { "<html><head><title>Test Property</title></head><body>Content</body></html>" }
    end

    trait :with_failed_scrape do
      scrape_successful { false }
      scrape_error_message { "Request blocked by Cloudflare or bot protection." }
      import_status { "pending" }
    end

    trait :imported do
      with_successful_scrape
      import_status { "imported" }
      imported_at { Time.current }
      association :realty_asset, factory: :pwb_realty_asset
    end

    trait :from_rightmove do
      source_url { "https://www.rightmove.co.uk/properties/123456789" }
      source_host { "www.rightmove.co.uk" }
      source_portal { "rightmove" }
    end

    trait :from_zoopla do
      source_url { "https://www.zoopla.co.uk/for-sale/details/12345678" }
      source_host { "www.zoopla.co.uk" }
      source_portal { "zoopla" }
    end

    trait :from_idealista do
      source_url { "https://www.idealista.com/inmueble/12345678/" }
      source_host { "www.idealista.com" }
      source_portal { "idealista" }
    end

    trait :generic do
      source_url { "https://www.example-realty.com/property/123" }
      source_host { "www.example-realty.com" }
      source_portal { "generic" }
    end
  end
end
