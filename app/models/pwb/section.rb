# oct 2017 - no longer in use - to_delete
module Pwb
  class Section < ApplicationRecord
    # translates :page_title, fallbacks_for_empty_translations: true
    # translates :link_title, fallbacks_for_empty_translations: true
    # globalize_accessors locales: I18n.available_locales
    # # [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]

    # attribute :link_title
    # attribute :page_title

    # has_many :contents, foreign_key: "section_key", primary_key: "link_path"

    # def as_json(options = nil)
    #   super({only: [
    #            :link_key, :link_path, :visible, :sort_order, :id,
    #            :show_in_top_nav, :show_in_footer, :is_page, :details
    #          ],
    #          methods: [:translation_key, :link_title_es, :page_title_es]
    #          }.merge(options || {}))
    # end

    # def translation_key
    #   return "navbar." + self.link_key
    # end

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
