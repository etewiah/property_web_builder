# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_listing_videos
# Database name: primary
#
#  id               :bigint           not null, primary key
#  branding         :jsonb
#  cost_cents       :integer          default(0)
#  duration_seconds :integer
#  error_message    :text
#  failed_at        :datetime
#  file_size_bytes  :integer
#  format           :string           default("vertical_9_16")
#  generated_at     :datetime
#  reference_number :string
#  resolution       :string
#  scenes           :jsonb
#  script           :text
#  share_token      :string
#  shared_at        :datetime
#  status           :string           default("pending")
#  style            :string           default("professional")
#  thumbnail_url    :string
#  title            :string           not null
#  video_url        :string
#  view_count       :integer          default(0)
#  voice            :string           default("nova")
#  voiceover_url    :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  realty_asset_id  :uuid             not null
#  render_id        :string
#  user_id          :bigint
#  website_id       :bigint           not null
#
# Indexes
#
#  index_pwb_listing_videos_on_realty_asset_id        (realty_asset_id)
#  index_pwb_listing_videos_on_render_id              (render_id)
#  index_pwb_listing_videos_on_share_token            (share_token) UNIQUE WHERE (share_token IS NOT NULL)
#  index_pwb_listing_videos_on_user_id                (user_id)
#  index_pwb_listing_videos_on_website_id             (website_id)
#  index_pwb_listing_videos_on_website_id_and_status  (website_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (realty_asset_id => pwb_realty_assets.id)
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
FactoryBot.define do
  factory :listing_video, class: 'Pwb::ListingVideo' do
    association :website
    association :realty_asset
    title { "Video for #{realty_asset&.street_address || 'Property'}" }
    status { 'pending' }
    format { 'vertical_9_16' }
    style { 'professional' }
    voice { 'nova' }

    trait :with_user do
      association :user
    end

    trait :generating do
      status { 'generating' }
    end

    trait :completed do
      status { 'completed' }
      generated_at { Time.current }
      video_url { 'https://example.com/video.mp4' }
      thumbnail_url { 'https://example.com/thumbnail.jpg' }
      voiceover_url { 'https://example.com/voiceover.mp3' }
      duration_seconds { 60 }
      resolution { '1080x1920' }
      file_size_bytes { 15_000_000 }
      render_id { "shotstack_#{SecureRandom.hex(8)}" }
      cost_cents { 12 }

      script { 'Welcome to this stunning 3-bedroom home in a prime location. The spacious living area features natural light throughout, while the modern kitchen offers all the amenities for comfortable living.' }

      scenes do
        [
          { photo_index: 0, duration: 5, caption: 'Welcome', transition: 'fade' },
          { photo_index: 1, duration: 5, caption: 'Living Room', transition: 'slide' },
          { photo_index: 2, duration: 5, caption: 'Kitchen', transition: 'slide' }
        ]
      end
    end

    trait :failed do
      status { 'failed' }
      error_message { 'Render failed: API error - insufficient credits' }
      failed_at { Time.current }
    end

    trait :shared do
      status { 'completed' }
      generated_at { 1.hour.ago }
      shared_at { Time.current }
      share_token { SecureRandom.urlsafe_base64(16) }
      view_count { 10 }
      video_url { 'https://example.com/video.mp4' }
      thumbnail_url { 'https://example.com/thumbnail.jpg' }
    end

    trait :horizontal do
      format { 'horizontal_16_9' }
      resolution { '1920x1080' }
    end

    trait :square do
      format { 'square_1_1' }
      resolution { '1080x1080' }
    end

    trait :luxury_style do
      style { 'luxury' }
    end

    trait :with_branding do
      branding do
        {
          logo_url: 'https://example.com/logo.png',
          company_name: 'Premier Realty',
          agent_name: 'John Smith',
          primary_color: '#2563eb'
        }
      end
    end

    trait :with_script do
      script { 'Welcome to this beautiful property featuring 3 bedrooms, 2 bathrooms, and a spacious backyard perfect for entertaining.' }

      scenes do
        [
          { photo_index: 0, duration: 5, caption: 'Welcome to your new home', transition: 'fade' },
          { photo_index: 1, duration: 6, caption: 'Spacious living area', transition: 'slide' },
          { photo_index: 2, duration: 5, caption: 'Modern kitchen', transition: 'zoom' },
          { photo_index: 3, duration: 5, caption: 'Master bedroom', transition: 'fade' },
          { photo_index: 4, duration: 4, caption: 'Contact us today', transition: 'dissolve' }
        ]
      end
    end
  end
end
