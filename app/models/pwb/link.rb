module Pwb
  class Link < ApplicationRecord
    translates :link_title, fallbacks_for_empty_translations: true
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]
    # enum placement: [ :top_nav, :footer ]
    # above method of declaring less flexible than below:
    enum placement: { top_nav: 0, footer: 1, social_media: 2 }

    scope :ordered_visible_top_nav, -> () { where(visible: true, placement: :top_nav).order('sort_order asc')  }

  end
end
