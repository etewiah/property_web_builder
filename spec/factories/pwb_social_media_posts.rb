# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_social_media_posts
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  call_to_action           :string
#  caption                  :text             not null
#  comments_count           :integer          default(0)
#  hashtags                 :text
#  likes_count              :integer          default(0)
#  link_url                 :string
#  platform                 :string           not null
#  post_type                :string           not null
#  postable_type            :string
#  reach_count              :integer          default(0)
#  scheduled_at             :datetime
#  selected_photos          :jsonb
#  shares_count             :integer          default(0)
#  status                   :string           default("draft")
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  ai_generation_request_id :bigint
#  postable_id              :uuid
#  website_id               :bigint           not null
#
# Indexes
#
#  index_pwb_social_media_posts_on_ai_generation_request_id       (ai_generation_request_id)
#  index_pwb_social_media_posts_on_postable_type_and_postable_id  (postable_type,postable_id)
#  index_pwb_social_media_posts_on_scheduled_at                   (scheduled_at)
#  index_pwb_social_media_posts_on_status                         (status)
#  index_pwb_social_media_posts_on_website_id                     (website_id)
#  index_pwb_social_media_posts_on_website_id_and_platform        (website_id,platform)
#
# Foreign Keys
#
#  fk_rails_...  (ai_generation_request_id => pwb_ai_generation_requests.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :pwb_social_media_post, class: 'Pwb::SocialMediaPost' do
    website
    association :postable, factory: :pwb_realty_asset

    platform { 'instagram' }
    post_type { 'feed' }
    caption { 'Check out this amazing property! Perfect for families looking for their dream home.' }
    hashtags { '#realestate #property #dreamhome #househunting #newlisting' }
    status { 'draft' }

    trait :instagram do
      platform { 'instagram' }
      hashtags { '#realestate #property #dreamhome #househunting #newlisting #instarealestate #homeforsale #luxuryhome #openhouse #realtor' }
    end

    trait :facebook do
      platform { 'facebook' }
      caption { 'Excited to share this beautiful new listing! This stunning property features modern amenities and is located in a prime location.' }
      hashtags { '#realestate #newlisting #dreamhome' }
    end

    trait :linkedin do
      platform { 'linkedin' }
      caption { 'New investment opportunity: This well-maintained property in a growing neighborhood offers excellent potential for both residential and investment purposes.' }
      hashtags { '#RealEstate #Investment #Property' }
    end

    trait :twitter do
      platform { 'twitter' }
      caption { 'New listing alert! This gem won\'t last long.' }
      hashtags { '#RealEstate #NewListing' }
    end

    trait :tiktok do
      platform { 'tiktok' }
      caption { 'POV: You just found your dream home' }
      hashtags { '#realestate #housetour #dreamhome #fyp #viral' }
    end

    trait :scheduled do
      status { 'scheduled' }
      scheduled_at { 1.day.from_now }
    end

    trait :published do
      status { 'published' }
    end

    trait :with_photos do
      after(:create) do |post|
        # Create associated photos if the postable is a realty_asset
        if post.postable.respond_to?(:prop_photos)
          3.times do |i|
            create(:prop_photo, prop: post.postable)
          end
          post.update!(selected_photos: post.postable.prop_photos.limit(3).map { |p| { id: p.id, suggested_crop: '1:1' } })
        end
      end
    end
  end
end
