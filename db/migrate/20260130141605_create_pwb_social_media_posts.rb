# frozen_string_literal: true

class CreatePwbSocialMediaPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_social_media_posts do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :ai_generation_request, foreign_key: { to_table: :pwb_ai_generation_requests }

      # Source listing (polymorphic - supports both integer and UUID foreign keys)
      t.string :postable_type
      t.uuid :postable_id

      # Platform and format
      t.string :platform, null: false  # instagram, facebook, linkedin, twitter, tiktok
      t.string :post_type, null: false # feed, story, reel, thread, article

      # Generated content
      t.text :caption, null: false
      t.text :hashtags
      t.jsonb :selected_photos, default: []  # Array of photo IDs with crop info
      t.string :call_to_action
      t.string :link_url

      # Scheduling
      t.datetime :scheduled_at
      t.string :status, default: 'draft'  # draft, scheduled, published, failed

      # Engagement tracking (for future analytics)
      t.integer :likes_count, default: 0
      t.integer :comments_count, default: 0
      t.integer :shares_count, default: 0
      t.integer :reach_count, default: 0

      t.timestamps
    end

    add_index :pwb_social_media_posts, [:website_id, :platform]
    add_index :pwb_social_media_posts, [:postable_type, :postable_id]
    add_index :pwb_social_media_posts, :status
    add_index :pwb_social_media_posts, :scheduled_at
  end
end
