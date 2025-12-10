# frozen_string_literal: true

require 'csv'

module Pwb
  # Content stores translatable content blocks for pages.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Content for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
  #
  class Content < ApplicationRecord
    extend Mobility

    self.table_name = 'pwb_contents'

    belongs_to :website, class_name: 'Pwb::Website', optional: true, touch: true

    has_many :content_photos, class_name: 'Pwb::ContentPhoto', foreign_key: 'content_id', dependent: :destroy
    has_many :page_contents, class_name: 'Pwb::PageContent', foreign_key: 'content_id'
    has_many :pages, through: :page_contents, class_name: 'Pwb::Page'

    # Mobility translations with container backend (single JSONB column)
    translates :raw

    def as_json(options = nil)
      super({
        only: ['key', 'page_part_key', 'visible_on_page'],
        methods: admin_attribute_names
      }.merge(options || {}))
    end

    def admin_attribute_names
      mobility_attribute_names + [:content_photos]
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

    def default_photo
      content_photos.first
    end

    def default_photo_url
      if content_photos.first
        content_photos.first.image_url
      else
        'https://placeholdit.imgix.net/~text?txtsize=38&txt=&w=550&h=300&txttrack=0'
      end
    end

    class << self
      def import(file)
        CSV.foreach(file.path, headers: true) do |row|
          if row.to_hash['locale'].present? && row.to_hash['key'].present?
            trsl = find_by_key(row['key']) || new
            trsl.attributes = row.to_hash.slice('key', 'value', 'locale')
            trsl.save!
          end
        end
      end

      def to_csv(export_column_names = nil)
        export_column_names ||= column_names
        CSV.generate do |csv|
          csv << export_column_names
          all.each do |content|
            csv << content.attributes.values_at(*export_column_names)
          end
        end
      end

      # Multi-tenant safe CSV export - scoped to specific website
      def to_csv_for_website(website, export_column_names = nil)
        export_column_names ||= column_names
        CSV.generate do |csv|
          csv << export_column_names
          where(website: website).each do |content|
            csv << content.attributes.values_at(*export_column_names)
          end
        end
      end
    end
  end
end
