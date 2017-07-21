module Pwb
  class Link < ApplicationRecord
    translates :link_title, fallbacks_for_empty_translations: true
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]
    # enum placement: [ :top_nav, :footer ]
    # above method of declaring less flexible than below:
    enum placement: { top_nav: 0, footer: 1, social_media: 2 }

    scope :ordered_visible_top_nav, -> () { where(visible: true, placement: :top_nav).order('sort_order asc')  }
    scope :ordered_visible_footer, -> () { where(visible: true, placement: :footer).order('sort_order asc')  }
    scope :ordered_top_nav, -> () { where(placement: :top_nav).order('sort_order asc')  }
    scope :ordered_footer, -> () { where(placement: :footer).order('sort_order asc')  }


    def as_json(options = nil)
      super({only: [
               "sort_order", "placement",
               "href_class", "is_deletable",
               "slug", "link_path","visible","link_title"
             ],
             methods: [
               "link_title_en","link_title_es",
               "link_title_de", "link_title_fr",
               "link_title_ru"
      ]}.merge(options || {}))
    end


  end
end
