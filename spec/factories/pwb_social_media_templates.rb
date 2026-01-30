# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_social_media_templates
# Database name: primary
#
#  id                :bigint           not null, primary key
#  active            :boolean          default(TRUE)
#  caption_template  :text             not null
#  category          :string
#  hashtag_template  :text
#  image_preferences :jsonb
#  is_default        :boolean          default(FALSE)
#  name              :string           not null
#  platform          :string           not null
#  post_type         :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  website_id        :bigint           not null
#
# Indexes
#
#  idx_on_website_id_platform_category_c9f0f62b45  (website_id,platform,category)
#  index_pwb_social_media_templates_on_website_id  (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_social_media_template, class: 'Pwb::SocialMediaTemplate' do
    website
    sequence(:name) { |n| "Template #{n}" }
    platform { 'instagram' }
    post_type { 'feed' }
    category { 'just_listed' }
    caption_template { 'Just listed! This beautiful {{ property_type }} in {{ city }} features {{ bedrooms }} bedrooms and is priced at {{ price }}.' }
    hashtag_template { '#realestate #{{ city | downcase }} #newlisting' }
    active { true }
    is_default { false }

    trait :instagram do
      platform { 'instagram' }
    end

    trait :facebook do
      platform { 'facebook' }
      caption_template { 'New on the market: A stunning {{ property_type }} in {{ city }}! {{ bedrooms }} bed, {{ bathrooms }} bath. Contact us for a showing!' }
    end

    trait :linkedin do
      platform { 'linkedin' }
      caption_template { 'Investment opportunity: {{ property_type }} in {{ city }} - {{ bedrooms }} bedrooms, {{ bathrooms }} bathrooms. Priced at {{ price }}. Contact me for more details.' }
      hashtag_template { '#RealEstate #Investment #{{ city }}' }
    end

    trait :twitter do
      platform { 'twitter' }
      caption_template { 'New listing: {{ bedrooms }}BR {{ property_type }} in {{ city }} at {{ price }}' }
      hashtag_template { '#RealEstate #NewListing' }
    end

    trait :price_drop do
      category { 'price_drop' }
      caption_template { 'Price reduced! This {{ property_type }} in {{ city }} is now {{ price }}. Don\'t miss this opportunity!' }
    end

    trait :open_house do
      category { 'open_house' }
      caption_template { 'Open House this weekend! Come see this beautiful {{ property_type }} in {{ city }}. {{ bedrooms }} bedrooms, priced at {{ price }}.' }
    end

    trait :sold do
      category { 'sold' }
      caption_template { 'SOLD! Congratulations to the new owners of this lovely {{ property_type }} in {{ city }}. Another successful transaction!' }
    end

    trait :default do
      is_default { true }
    end

    trait :inactive do
      active { false }
    end
  end
end
