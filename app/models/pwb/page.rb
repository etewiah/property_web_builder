module Pwb
# added July 2017
  class Page < ApplicationRecord
    translates :raw_html, fallbacks_for_empty_translations: true
    translates :page_title, fallbacks_for_empty_translations: true
    translates :link_title, fallbacks_for_empty_translations: true
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]

    has_many :links, foreign_key: "page_slug", primary_key: "slug"
    has_one :main_link, -> { where(placement: :top_nav) }, foreign_key: "page_slug", primary_key: "slug", class_name: "Pwb::Link"
    # , :conditions => ['placement = ?', :admin]

    # TODO - change col in migration
    scope :visible_in_admin, -> () { where visible: true  }

    def as_json(options = nil)
      super({only: [
               "sort_order_top_nav", "show_in_top_nav",
               "sort_order_footer", "show_in_footer",
               "slug", "link_path","details","visible"
             ],
             methods: [
               "link_title_en","link_title_es",
               "link_title_de", "link_title_fr",
               "link_title_ru",
               "page_title_en","page_title_es",
               "page_title_de", "page_title_fr",
               "page_title_ru",
               "raw_html_en","raw_html_es",
               "raw_html_de", "raw_html_fr",
               "raw_html_ru",
      ]}.merge(options || {}))
    end
    # above can be called on a result set from a query like so:
    # Page.all.as_json
    # Below can only be called on a single record like so:
    # Page.first.as_json
    def as_json_summary(options = nil)
      as_json({only: [
                 "sort_order_top_nav", "show_in_top_nav",
                 "sort_order_footer", "show_in_footer",
                 "slug", "link_path"
               ],
               methods: ["link_title_en","link_title_es", "link_title_de",
                         "link_title_ru", "link_title_fr"]}.merge(options || {}))
    end
  end
end
