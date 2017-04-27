module Pwb
  class Section < ApplicationRecord
    translates :page_title, fallbacks_for_empty_translations: true
    translates :link_title, fallbacks_for_empty_translations: true
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar]

    has_many :contents, foreign_key: "section_key"
  end
end
