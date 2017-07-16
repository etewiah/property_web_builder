module Pwb
  class Page < ApplicationRecord
    translates :raw_html, fallbacks_for_empty_translations: true
    translates :page_title, fallbacks_for_empty_translations: true
    translates :link_title, fallbacks_for_empty_translations: true
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]
  end
end
