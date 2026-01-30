# frozen_string_literal: true

class CreatePwbSocialMediaTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :pwb_social_media_templates do |t|
      t.references :website, null: false, foreign_key: { to_table: :pwb_websites }

      t.string :name, null: false
      t.string :platform, null: false
      t.string :post_type, null: false
      t.string :category  # just_listed, price_drop, open_house, sold, market_update

      t.text :caption_template, null: false  # With placeholders like {{property_type}}, {{price}}
      t.text :hashtag_template
      t.jsonb :image_preferences, default: {}  # preferred aspect ratio, filters, etc.

      t.boolean :active, default: true
      t.boolean :is_default, default: false

      t.timestamps
    end

    add_index :pwb_social_media_templates, [:website_id, :platform, :category]
  end
end
