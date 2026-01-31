# frozen_string_literal: true

class CreatePwbListingVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :pwb_listing_videos do |t|
      # References
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :user, foreign_key: { to_table: :pwb_users }
      t.uuid :realty_asset_id, null: false

      # Video metadata
      t.string :title, null: false
      t.string :reference_number
      t.string :status, default: 'pending'  # pending, generating, completed, failed

      # Generation options
      t.string :format, default: 'vertical_9_16'  # vertical_9_16, horizontal_16_9, square_1_1
      t.string :style, default: 'professional'    # professional, luxury, casual, energetic, minimal
      t.string :voice, default: 'nova'            # OpenAI TTS voices

      # Content
      t.text :script                    # AI-generated voiceover script
      t.jsonb :scenes, default: []      # Scene breakdown with durations
      t.jsonb :branding, default: {}    # Logo, colors, company info

      # Generated assets
      t.string :video_url               # Final video URL
      t.string :thumbnail_url           # Video thumbnail
      t.string :voiceover_url           # Generated audio URL

      # Metadata
      t.integer :duration_seconds
      t.string :resolution              # e.g., "1080x1920"
      t.integer :file_size_bytes

      # External service tracking
      t.string :render_id               # Shotstack render ID
      t.integer :cost_cents, default: 0 # Total generation cost

      # Sharing
      t.string :share_token
      t.datetime :generated_at
      t.datetime :shared_at
      t.integer :view_count, default: 0

      # Error tracking
      t.text :error_message
      t.datetime :failed_at

      t.timestamps
    end

    # Indexes for common queries
    add_index :pwb_listing_videos, [:website_id, :status]
    add_index :pwb_listing_videos, :share_token, unique: true, where: "share_token IS NOT NULL"
    add_index :pwb_listing_videos, :realty_asset_id
    add_index :pwb_listing_videos, :render_id

    # Foreign key for realty_asset (uuid reference)
    add_foreign_key :pwb_listing_videos, :pwb_realty_assets, column: :realty_asset_id
  end
end
