# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_realty_games
# Database name: primary
#
#  id                       :uuid             not null, primary key
#  active                   :boolean          default(TRUE), not null
#  bg_image_url             :string
#  default_country          :string
#  default_currency         :string           default("EUR"), not null
#  description              :text
#  end_at                   :datetime
#  estimates_count          :integer          default(0), not null
#  hidden_from_landing_page :boolean          default(FALSE), not null
#  sessions_count           :integer          default(0), not null
#  slug                     :string           not null
#  start_at                 :datetime
#  title                    :string           not null
#  validation_rules         :jsonb            not null
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  website_id               :bigint           not null
#
# Indexes
#
#  index_pwb_realty_games_on_website_id             (website_id)
#  index_pwb_realty_games_on_website_id_and_active  (website_id,active)
#  index_pwb_realty_games_on_website_id_and_slug    (website_id,slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_realty_game, class: 'Pwb::RealtyGame' do
    association :website, factory: :pwb_website
    sequence(:slug) { |n| "game-#{n}" }
    sequence(:title) { |n| "Property Challenge #{n}" }
    description { 'Can you guess the property prices?' }
    default_currency { 'EUR' }
    active { true }
    hidden_from_landing_page { false }

    trait :inactive do
      active { false }
    end

    trait :hidden do
      hidden_from_landing_page { true }
    end

    trait :scheduled do
      start_at { 1.day.from_now }
      end_at { 1.month.from_now }
    end

    trait :with_listings do
      after(:create) do |game|
        create_list(:pwb_game_listing, 3, realty_game: game)
      end
    end
  end
end
