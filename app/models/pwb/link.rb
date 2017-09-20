module Pwb
# added July 2017
  class Link < ApplicationRecord
    translates :link_title, fallbacks_for_empty_translations: true
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]

    belongs_to :page, foreign_key: "page_slug", primary_key: "slug"

    # below needed to avoid "... is not an attribute known to Active Record" warnings
    attribute :link_title


    # enum placement: [ :top_nav, :footer ]
    # above method of declaring less flexible than below:
    enum placement: { top_nav: 0, footer: 1, social_media: 2, admin: 3}

    scope :ordered_visible_admin, -> () { where(visible: true, placement: :admin).order('sort_order asc')  }
    scope :ordered_visible_top_nav, -> () { where(visible: true, placement: :top_nav).order('sort_order asc')  }
    scope :ordered_visible_footer, -> () { where(visible: true, placement: :footer).order('sort_order asc')  }
    scope :ordered_top_nav, -> () { where(placement: :top_nav).order('sort_order asc')  }
    scope :ordered_footer, -> () { where(placement: :footer).order('sort_order asc')  }


    def as_json(options = nil)
      super({only: [
               "sort_order", "placement",
               "href_class", "is_deletable",
               "slug", "link_path","visible",
               "link_title", "page_slug"
             ],
             methods: admin_attribute_names}.merge(options || {}))
    end

    def admin_attribute_names
      self.globalize_attribute_names
      # self.globalize_attribute_names.push :content_photos
    end

  end
end
