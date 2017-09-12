module Pwb
  # added July 2017
  # has details json col where page_fragment info is stored
  class Page < ApplicationRecord
    extend ActiveHash::Associations::ActiveRecordExtensions
    belongs_to_active_hash :page_setup, optional: true, foreign_key: "slug", class_name: "Pwb::PageSetup", shortcuts: [:friendly_name], primary_key: "name"
    has_many :links, foreign_key: "page_slug", primary_key: "slug"
    has_one :main_link, -> { where(placement: :top_nav) }, foreign_key: "page_slug", primary_key: "slug", class_name: "Pwb::Link"
    # , :conditions => ['placement = ?', :admin]

    translates :raw_html, fallbacks_for_empty_translations: true
    translates :page_title, fallbacks_for_empty_translations: true
    translates :link_title, fallbacks_for_empty_translations: true
    # globalize_accessors locales: [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]
    globalize_accessors locales: I18n.available_locales

    # Pwb::Page.has_attribute?("raw_html")
    # below needed so above returns true
    attribute :link_title
    attribute :page_title
    attribute :raw_html
    # without above, Rails 5.1 will give deprecation warnings in my specs

    # scope :visible_in_admin, -> () { where visible: true  }

    def set_fragment_details label, locale, fragment_blocks, fragment_html
      fragments = details["fragments"].present? ? details["fragments"] : {}
      label_fragments = fragments["label"].present? ? fragments["label"] : { label => {}}
      locale_label_fragments = label_fragments[locale].present? ? label_fragments[locale] : { label => { locale => fragment_blocks  }}
      details["fragments"] = locale_label_fragments 
      details["fragments"][label][locale]["html"] = fragment_html
    end

    # def as_json(options = nil)
    #   super({only: [
    #            "sort_order_top_nav", "show_in_top_nav",
    #            "sort_order_footer", "show_in_footer",
    #            "slug", "link_path","details","visible"
    #          ],
    #          methods: [
    #            "link_title_en","link_title_es",
    #            "link_title_de", "link_title_fr",
    #            "link_title_ru",
    #            "page_title_en","page_title_es",
    #            "page_title_de", "page_title_fr",
    #            "page_title_ru",
    #            "raw_html_en","raw_html_es",
    #            "raw_html_de", "raw_html_fr",
    #            "raw_html_ru",
    #   ]}.merge(options || {}))
    # end
    # above can be called on a result set from a query like so:
    # Page.all.as_json
    # Below can only be called on a single record like so:
    # Page.first.as_json
    def as_json_for_admin(options = nil)
      as_json({only: [
                 "sort_order_top_nav", "show_in_top_nav",
                 "sort_order_footer", "show_in_footer",
                 "slug", "link_path","visible"
               ],
               methods: admin_globalize_attribute_names}.merge(options || {}))
    end

    def admin_globalize_attribute_names

      self.globalize_attribute_names.push :page_fragments, :fragment_configs, :page_setup
      # return "link_title_en","link_title_es", "link_title_de",
      #                    "link_title_ru", "link_title_fr"
    end

    def fragment_configs
      return details["cmsPartsList"]
    end

    def page_fragments
      return details["fragments"]
    end
  end
end
