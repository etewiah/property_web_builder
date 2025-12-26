# frozen_string_literal: true

class CreatePwbMedia < ActiveRecord::Migration[7.0]
  def change
    # Media folders for organization
    create_table :pwb_media_folders do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.string :name, null: false
      t.string :slug
      t.references :parent, foreign_key: { to_table: :pwb_media_folders }
      t.integer :sort_order, default: 0
      t.timestamps
    end

    add_index :pwb_media_folders, [:website_id, :slug], unique: true
    add_index :pwb_media_folders, [:website_id, :parent_id]

    # Main media table
    create_table :pwb_media do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }
      t.references :folder, foreign_key: { to_table: :pwb_media_folders }
      
      # File metadata
      t.string :filename, null: false
      t.string :content_type
      t.bigint :byte_size
      t.string :checksum
      
      # Dimensions (for images)
      t.integer :width
      t.integer :height
      
      # User-editable metadata
      t.string :title
      t.string :alt_text
      t.text :description
      t.string :caption
      
      # Organization
      t.string :tags, array: true, default: []
      t.integer :sort_order, default: 0
      
      # Usage tracking
      t.integer :usage_count, default: 0
      t.datetime :last_used_at
      
      # Source tracking (for imports)
      t.string :source_url
      t.string :source_type  # 'upload', 'url', 'import'
      
      t.timestamps
    end

    add_index :pwb_media, [:website_id, :folder_id]
    add_index :pwb_media, [:website_id, :content_type]
    add_index :pwb_media, [:website_id, :created_at]
    add_index :pwb_media, :tags, using: :gin
  end
end
