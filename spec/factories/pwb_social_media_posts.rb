# frozen_string_literal: true

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
