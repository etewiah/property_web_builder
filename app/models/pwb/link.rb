# frozen_string_literal: true

module Pwb
  # Link represents navigation links for a website.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Link for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class Link < ApplicationRecord
    extend Mobility

    self.table_name = 'pwb_links'

    belongs_to :website, class_name: 'Pwb::Website', optional: true, touch: true

    # Mobility translations with container backend (single JSONB column)
    translates :link_title

    belongs_to :page, optional: true, class_name: 'Pwb::Page', foreign_key: 'page_slug', primary_key: 'slug'

    enum :placement, { top_nav: 0, footer: 1, social_media: 2, admin: 3 }

    # Scopes
    scope :ordered_visible_admin, -> { where(visible: true, placement: :admin).order('sort_order asc') }
    scope :ordered_visible_top_nav, -> { where(visible: true, placement: :top_nav).order('sort_order asc') }
    scope :ordered_visible_footer, -> { where(visible: true, placement: :footer).order('sort_order asc') }
    scope :ordered_top_nav, -> { where(placement: :top_nav).order('sort_order asc') }
    scope :ordered_footer, -> { where(placement: :footer).order('sort_order asc') }

    def as_json(options = nil)
      super({
        only: %w[sort_order placement href_class is_deletable slug link_path visible link_title page_slug],
        methods: admin_attribute_names
      }.merge(options || {}))
    end

    def admin_attribute_names
      mobility_attribute_names
    end

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
