# frozen_string_literal: true

module Pwb
  # Records AI-generated listing videos.
  #
  # Each video captures:
  # - Subject property
  # - AI-generated script and scenes
  # - Generated voiceover audio
  # - Final assembled video
  #
  # Multi-tenant: Scoped by website_id
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
  #
  class ListingVideo < ApplicationRecord
    self.table_name = "pwb_listing_videos"

    # Associations
    belongs_to :website
    belongs_to :user, class_name: "Pwb::User", optional: true
    belongs_to :realty_asset, class_name: "Pwb::RealtyAsset"

    # Attach video and thumbnail files
    has_one_attached :video_file
    has_one_attached :thumbnail_file
    has_one_attached :voiceover_file

    # Constants
    FORMATS = %w[vertical_9_16 horizontal_16_9 square_1_1].freeze
    STYLES = %w[professional luxury casual energetic minimal].freeze
    VOICES = %w[alloy echo fable onyx nova shimmer].freeze
    STATUSES = %w[pending generating completed failed].freeze

    # Validations
    validates :title, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :format, inclusion: { in: FORMATS }
    validates :style, inclusion: { in: STYLES }
    validates :voice, inclusion: { in: VOICES }
    validates :share_token, uniqueness: true, allow_nil: true

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :completed, -> { where(status: "completed") }
    scope :pending, -> { where(status: "pending") }
    scope :generating, -> { where(status: "generating") }
    scope :failed, -> { where(status: "failed") }
    scope :for_property, ->(property_id) { where(realty_asset_id: property_id) }

    # Callbacks
    before_create :generate_reference_number
    before_create :set_default_branding

    # State transitions
    def mark_generating!
      update!(status: "generating")
    end

    def mark_completed!(attrs = {})
      update!(
        attrs.merge(
          status: "completed",
          generated_at: Time.current,
          error_message: nil,
          failed_at: nil
        )
      )
    end

    def mark_failed!(message)
      update!(
        status: "failed",
        error_message: message,
        failed_at: Time.current
      )
    end

    def mark_shared!
      update!(
        shared_at: Time.current,
        share_token: generate_share_token
      )
    end

    # Status helpers
    def pending?
      status == "pending"
    end

    def generating?
      status == "generating"
    end

    def completed?
      status == "completed"
    end

    def failed?
      status == "failed"
    end

    # Video helpers
    def video_ready?
      video_url.present? || video_file.attached?
    end

    def thumbnail_ready?
      thumbnail_url.present? || thumbnail_file.attached?
    end

    def video_filename
      "listing_video_#{reference_number}.mp4"
    end

    # Increment view count
    def record_view!
      increment!(:view_count)
    end

    # Format helpers
    def format_label
      case format
      when "vertical_9_16" then "Vertical (9:16)"
      when "horizontal_16_9" then "Horizontal (16:9)"
      when "square_1_1" then "Square (1:1)"
      else format.titleize
      end
    end

    def aspect_ratio
      case format
      when "vertical_9_16" then "9:16"
      when "horizontal_16_9" then "16:9"
      when "square_1_1" then "1:1"
      else "9:16"
      end
    end

    # Duration helpers
    def duration_formatted
      return nil unless duration_seconds

      minutes = duration_seconds / 60
      seconds = duration_seconds % 60
      format("%d:%02d", minutes, seconds)
    end

    # Cost helpers
    def cost_formatted
      return nil unless cost_cents

      "$#{(cost_cents / 100.0).round(2)}"
    end

    # Branding accessors
    def logo_url
      branding&.dig("logo_url")
    end

    def company_name
      branding&.dig("company_name") || website&.company_display_name
    end

    def agent_name
      branding&.dig("agent_name") || user&.display_name
    end

    def primary_color
      branding&.dig("primary_color") || "#2563eb"
    end

    # Scene accessors
    def scene_count
      scenes&.length || 0
    end

    def total_scene_duration
      scenes&.sum { |s| s["duration"] || s[:duration] || 0 } || 0
    end

    private

    def generate_reference_number
      self.reference_number ||= "VID-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.alphanumeric(6).upcase}"
    end

    def generate_share_token
      SecureRandom.urlsafe_base64(16)
    end

    def set_default_branding
      return if branding.present?

      self.branding = {
        logo_url: website&.main_logo_url,
        company_name: website&.company_display_name,
        agent_name: user&.display_name,
        primary_color: website&.primary_color || "#2563eb"
      }.compact
    end
  end
end
