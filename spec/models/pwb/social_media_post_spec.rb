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
#  postable_id              :bigint
#  website_id               :bigint           not null
#
# Indexes
#
#  index_pwb_social_media_posts_on_ai_generation_request_id       (ai_generation_request_id)
#  index_pwb_social_media_posts_on_postable                       (postable_type,postable_id)
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
require 'rails_helper'

RSpec.describe Pwb::SocialMediaPost, type: :model do
  let(:website) { create(:website) }
  let(:property) { create(:pwb_realty_asset, website: website) }

  describe 'associations' do
    it { is_expected.to belong_to(:website) }
    it { is_expected.to belong_to(:ai_generation_request).optional }
    it { is_expected.to belong_to(:postable) }
  end

  describe 'validations' do
    subject { build(:pwb_social_media_post, website: website, postable: property) }

    it { is_expected.to validate_presence_of(:platform) }
    it { is_expected.to validate_presence_of(:post_type) }
    it { is_expected.to validate_presence_of(:caption) }

    it 'validates platform inclusion' do
      expect(subject).to allow_value('instagram').for(:platform)
      expect(subject).to allow_value('facebook').for(:platform)
      expect(subject).to allow_value('linkedin').for(:platform)
      expect(subject).to allow_value('twitter').for(:platform)
      expect(subject).to allow_value('tiktok').for(:platform)
      expect(subject).not_to allow_value('myspace').for(:platform)
    end

    it 'validates post_type inclusion' do
      expect(subject).to allow_value('feed').for(:post_type)
      expect(subject).to allow_value('story').for(:post_type)
      expect(subject).to allow_value('reel').for(:post_type)
      expect(subject).not_to allow_value('invalid').for(:post_type)
    end

    it 'validates status inclusion' do
      expect(subject).to allow_value('draft').for(:status)
      expect(subject).to allow_value('scheduled').for(:status)
      expect(subject).to allow_value('published').for(:status)
      expect(subject).to allow_value('failed').for(:status)
      expect(subject).not_to allow_value('pending').for(:status)
    end
  end

  describe 'caption length validation' do
    it 'allows caption within Twitter limit' do
      post = build(:pwb_social_media_post, :twitter, website: website, postable: property)
      post.caption = 'A' * 280
      expect(post).to be_valid
    end

    it 'rejects caption exceeding Twitter limit' do
      post = build(:pwb_social_media_post, :twitter, website: website, postable: property)
      post.caption = 'A' * 281
      expect(post).not_to be_valid
      expect(post.errors[:caption]).to include('exceeds 280 character limit for twitter')
    end

    it 'allows long captions for Instagram' do
      post = build(:pwb_social_media_post, :instagram, website: website, postable: property)
      post.caption = 'A' * 2200
      expect(post).to be_valid
    end

    it 'rejects caption exceeding Instagram limit' do
      post = build(:pwb_social_media_post, :instagram, website: website, postable: property)
      post.caption = 'A' * 2201
      expect(post).not_to be_valid
    end
  end

  describe 'scopes' do
    before do
      create(:pwb_social_media_post, :instagram, website: website, postable: property)
      create(:pwb_social_media_post, :facebook, website: website, postable: property)
      create(:pwb_social_media_post, :instagram, :scheduled, website: website, postable: property)
      create(:pwb_social_media_post, :instagram, :published, website: website, postable: property)
    end

    describe '.for_platform' do
      it 'filters by platform' do
        expect(Pwb::SocialMediaPost.for_platform('instagram').count).to eq(3)
        expect(Pwb::SocialMediaPost.for_platform('facebook').count).to eq(1)
      end
    end

    describe '.drafts' do
      it 'returns only draft posts' do
        expect(Pwb::SocialMediaPost.drafts.count).to eq(2)
      end
    end

    describe '.scheduled' do
      it 'returns only scheduled posts' do
        expect(Pwb::SocialMediaPost.scheduled.count).to eq(1)
      end
    end

    describe '.published' do
      it 'returns only published posts' do
        expect(Pwb::SocialMediaPost.published.count).to eq(1)
      end
    end

    describe '.upcoming' do
      it 'returns scheduled posts with future dates' do
        upcoming = Pwb::SocialMediaPost.upcoming
        expect(upcoming.count).to eq(1)
        expect(upcoming.first.scheduled_at).to be > Time.current
      end
    end
  end

  describe '#full_caption' do
    it 'combines caption and hashtags' do
      post = build(:pwb_social_media_post, caption: 'Great property!', hashtags: '#realestate #home')
      expect(post.full_caption).to eq("Great property!\n\n#realestate #home")
    end

    it 'returns just caption if no hashtags' do
      post = build(:pwb_social_media_post, caption: 'Great property!', hashtags: nil)
      expect(post.full_caption).to eq('Great property!')
    end
  end

  describe '#hashtag_count' do
    it 'counts hashtags correctly' do
      post = build(:pwb_social_media_post, hashtags: '#one #two #three')
      expect(post.hashtag_count).to eq(3)
    end

    it 'returns 0 for empty hashtags' do
      post = build(:pwb_social_media_post, hashtags: nil)
      expect(post.hashtag_count).to eq(0)
    end
  end

  describe '#within_hashtag_limit?' do
    it 'returns true when within limit' do
      post = build(:pwb_social_media_post, :twitter, hashtags: '#one #two')
      expect(post.within_hashtag_limit?).to be true
    end

    it 'returns false when exceeding limit' do
      post = build(:pwb_social_media_post, :twitter, hashtags: '#one #two #three #four')
      expect(post.within_hashtag_limit?).to be false
    end

    it 'returns true for unlimited platforms' do
      post = build(:pwb_social_media_post, :facebook, hashtags: '#' + (1..100).map { |i| "tag#{i}" }.join(' #'))
      expect(post.within_hashtag_limit?).to be true
    end
  end

  describe '#schedule!' do
    let(:post) { create(:pwb_social_media_post, website: website, postable: property) }

    it 'sets scheduled_at and status' do
      scheduled_time = 1.week.from_now
      post.schedule!(scheduled_time)

      expect(post.scheduled_at).to be_within(1.second).of(scheduled_time)
      expect(post.status).to eq('scheduled')
    end
  end

  describe '#publish!' do
    let(:post) { create(:pwb_social_media_post, :scheduled, website: website, postable: property) }

    it 'sets status to published' do
      post.publish!
      expect(post.status).to eq('published')
    end
  end

  describe 'status helper methods' do
    it 'returns correct boolean for draft?' do
      post = build(:pwb_social_media_post, status: 'draft')
      expect(post.draft?).to be true
      expect(post.scheduled?).to be false
    end

    it 'returns correct boolean for scheduled?' do
      post = build(:pwb_social_media_post, status: 'scheduled')
      expect(post.scheduled?).to be true
      expect(post.draft?).to be false
    end

    it 'returns correct boolean for published?' do
      post = build(:pwb_social_media_post, status: 'published')
      expect(post.published?).to be true
    end
  end
end
