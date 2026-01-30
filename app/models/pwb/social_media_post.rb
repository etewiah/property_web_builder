# frozen_string_literal: true

module Pwb
  # Stores AI-generated social media posts for property listings.
  #
  # Each post is platform-specific (Instagram, Facebook, LinkedIn, Twitter, TikTok)
  # and includes captions, hashtags, and photo selections optimized for that platform.
  #
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
  # Multi-tenant: Scoped by website_id
  class SocialMediaPost < ApplicationRecord
    self.table_name = "pwb_social_media_posts"

    # Associations
    belongs_to :website
    belongs_to :ai_generation_request, optional: true
    belongs_to :postable, polymorphic: true

    # Enums stored as strings for clarity
    PLATFORMS = %w[instagram facebook linkedin twitter tiktok].freeze
    POST_TYPES = %w[feed story reel thread article].freeze
    STATUSES = %w[draft scheduled published failed].freeze

    # Platform-specific limits
    CAPTION_LIMITS = {
      instagram: 2200,
      facebook: 63_206,
      linkedin: 3000,
      twitter: 280,
      tiktok: 2200
    }.freeze

    HASHTAG_LIMITS = {
      instagram: 30,
      facebook: nil, # unlimited
      linkedin: 5,
      twitter: 3,
      tiktok: 8
    }.freeze

    # Validations
    validates :platform, presence: true, inclusion: { in: PLATFORMS }
    validates :post_type, presence: true, inclusion: { in: POST_TYPES }
    validates :status, inclusion: { in: STATUSES }
    validates :caption, presence: true
    validate :caption_length_for_platform

    # Scopes
    scope :for_platform, ->(platform) { where(platform: platform) }
    scope :drafts, -> { where(status: "draft") }
    scope :scheduled, -> { where(status: "scheduled") }
    scope :published, -> { where(status: "published") }
    scope :upcoming, -> { scheduled.where("scheduled_at > ?", Time.current).order(:scheduled_at) }
    scope :recent, -> { order(created_at: :desc) }

    # Callbacks
    before_validation :set_default_status, on: :create

    # Instance methods
    def caption_length_for_platform
      return unless caption.present? && platform.present?

      limit = CAPTION_LIMITS[platform.to_sym]
      return unless limit && caption.length > limit

      errors.add(:caption, "exceeds #{limit} character limit for #{platform}")
    end

    def full_caption
      [caption, hashtags].compact_blank.join("\n\n")
    end

    def hashtag_count
      return 0 if hashtags.blank?

      hashtags.scan(/#\w+/).count
    end

    def within_hashtag_limit?
      limit = HASHTAG_LIMITS[platform.to_sym]
      return true if limit.nil? # No limit

      hashtag_count <= limit
    end

    def selected_photo_records
      return [] if selected_photos.blank?

      photo_ids = selected_photos.map { |p| p["id"] || p[:id] }
      PropPhoto.where(id: photo_ids).index_by(&:id).values_at(*photo_ids).compact
    end

    def character_count
      full_caption.length
    end

    def draft?
      status == "draft"
    end

    def scheduled?
      status == "scheduled"
    end

    def published?
      status == "published"
    end

    def schedule!(time)
      update!(scheduled_at: time, status: "scheduled")
    end

    def publish!
      update!(status: "published")
    end

    def mark_failed!(error = nil)
      update!(status: "failed")
    end

    private

    def set_default_status
      self.status ||= "draft"
    end
  end
end
