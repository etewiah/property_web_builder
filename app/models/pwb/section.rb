module Pwb
  class Section < ApplicationRecord
    translates :page_title, fallbacks_for_empty_translations: true
    translates :link_title, fallbacks_for_empty_translations: true
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]

    has_many :contents, foreign_key: "section_key", primary_key: "link_path"


    # t.string :link_key
    # t.string :link_path
    # t.integer :sort_order
    # t.boolean :visible
    # t.timestamps null: false
    # add_column :pwb_sections, :flags, :integer, default: 0, index: true, null: false
    # add_column :pwb_sections, :details, :json, default: {}
    # add_column :pwb_sections, :is_page, :boolean, default: false, index: true
    # add_column :pwb_sections, :show_in_top_nav, :boolean, default: false, index: true
    # add_column :pwb_sections, :show_in_footer, :boolean, default: false, index: true
    # add_column :pwb_sections, :key, :string, index: true
  end
end
