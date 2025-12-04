# frozen_string_literal: true

class AddMobilityTranslationsColumns < ActiveRecord::Migration[7.0]
  def change
    # Add JSONB translations column to each table that uses Globalize

    # Pwb::Prop - translates :title, :description
    add_column :pwb_props, :translations, :jsonb, default: {}, null: false
    add_index :pwb_props, :translations, using: :gin

    # Pwb::Page - translates :raw_html, :page_title, :link_title
    add_column :pwb_pages, :translations, :jsonb, default: {}, null: false
    add_index :pwb_pages, :translations, using: :gin

    # Pwb::Content - translates :raw
    add_column :pwb_contents, :translations, :jsonb, default: {}, null: false
    add_index :pwb_contents, :translations, using: :gin

    # Pwb::Link - translates :link_title
    add_column :pwb_links, :translations, :jsonb, default: {}, null: false
    add_index :pwb_links, :translations, using: :gin
  end
end
