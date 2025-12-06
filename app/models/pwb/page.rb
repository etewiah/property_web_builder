# frozen_string_literal: true

module Pwb
  # Page represents a CMS page for a website.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Page for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class Page < ApplicationRecord
    extend Mobility
    extend ActiveHash::Associations::ActiveRecordExtensions

    self.table_name = 'pwb_pages'

    belongs_to :website, class_name: 'Pwb::Website', optional: true

    # Mobility translations with container backend (single JSONB column)
    translates :raw_html, :page_title, :link_title

    has_many :links, class_name: 'Pwb::Link', foreign_key: 'page_slug', primary_key: 'slug'
    has_one :main_link, -> { where(placement: :top_nav) }, foreign_key: 'page_slug', primary_key: 'slug', class_name: 'Pwb::Link'

    has_many :page_parts, class_name: 'Pwb::PagePart', foreign_key: 'page_slug', primary_key: 'slug'

    has_many :page_contents, class_name: 'Pwb::PageContent'
    has_many :contents, through: :page_contents, class_name: 'Pwb::Content'
    has_many :ordered_visible_page_contents, -> { ordered_visible }, class_name: 'Pwb::PageContent'

    def get_page_part(page_part_key)
      page_parts.where(page_part_key: page_part_key, website_id: website_id).first
    end

    def create_fragment_photo(page_part_key, block_label, photo_file)
      page_fragment_content = contents.find_or_create_by(page_part_key: page_part_key)

      return nil if ENV['RAILS_ENV'] == 'test'

      begin
        photo = page_fragment_content.content_photos.create(block_key: block_label)
        photo.image = photo_file
        photo.save!
      rescue StandardError => e
        print e
      end
      photo
    end

    def set_fragment_visibility(page_part_key, visible_on_page)
      page_content_join_model = page_contents.find_or_create_by(page_part_key: page_part_key, website_id: website_id)
      page_content_join_model.visible_on_page = visible_on_page
      page_content_join_model.save!
    end

    def set_fragment_html(page_part_key, locale, new_fragment_html)
      page_fragment_content = contents.find_or_create_by(page_part_key: page_part_key)
      content_html_col = "raw_#{locale}="
      page_fragment_content.send(content_html_col, new_fragment_html)
      page_fragment_content.save!
      page_fragment_content
    end

    def update_page_part_content(page_part_key, locale, fragment_block)
      json_fragment_block = set_page_part_block_contents(page_part_key, locale, fragment_block)
      fragment_html = rebuild_page_content(page_part_key, locale)
      { json_fragment_block: json_fragment_block, fragment_html: fragment_html }
    end

    def as_json(options = nil)
      super({
        only: %w[id sort_order_top_nav show_in_top_nav sort_order_footer show_in_footer slug link_path visible page_title link_title raw_html],
        methods: [:page_contents]
      }.merge(options || {}))
    end

    def as_json_for_admin(options = nil)
      as_json({
        only: %w[sort_order_top_nav show_in_top_nav sort_order_footer show_in_footer slug link_path visible],
        methods: admin_attribute_names
      }.merge(options || {}))
    end

    def admin_attribute_names
      mobility_attribute_names + [:page_contents, :page_parts]
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

    private
  end
end
