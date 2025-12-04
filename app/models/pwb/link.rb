module Pwb
  # added July 2017
  class Link < ApplicationRecord
    extend Mobility

    belongs_to :website, optional: true

    # Mobility translations with container backend (single JSONB column)
    # Fallbacks configured globally in mobility.rb initializer
    translates :link_title

    belongs_to :page, optional: true, foreign_key: "page_slug", primary_key: "slug"

    # enum placement: [ :top_nav, :footer ]
    # above method of declaring less flexible than below:
    enum :placement, { top_nav: 0, footer: 1, social_media: 2, admin: 3 }

    # Scopes - removed includes(:translations) as JSONB doesn't require eager loading
    scope :ordered_visible_admin, -> { where(visible: true, placement: :admin).order("sort_order asc") }
    scope :ordered_visible_top_nav, -> { where(visible: true, placement: :top_nav).order("sort_order asc") }
    scope :ordered_visible_footer, -> { where(visible: true, placement: :footer).order("sort_order asc") }
    scope :ordered_top_nav, -> { where(placement: :top_nav).order("sort_order asc") }
    scope :ordered_footer, -> { where(placement: :footer).order("sort_order asc") }

    def as_json(options = nil)
      super({ only: [
        "sort_order", "placement",
        "href_class", "is_deletable",
        "slug", "link_path", "visible",
        "link_title", "page_slug",
      ],
              methods: admin_attribute_names }.merge(options || {}))
    end

    def admin_attribute_names
      # Returns locale-specific attribute names for serialization (replaces globalize_attribute_names)
      mobility_attribute_names
    end

    # Helper method to generate locale-specific attribute names
    def mobility_attribute_names
      attributes = []
      self.class.mobility_attributes.each do |attr|
        I18n.available_locales.each do |locale|
          attributes << "#{attr}_#{locale}".to_sym
        end
      end
      attributes
    end
  end
end
