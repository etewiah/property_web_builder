module Pwb
  class Content < ApplicationRecord
    extend Mobility

    belongs_to :website, optional: true
    has_many :content_photos, dependent: :destroy
    # belongs_to :section, optional: true, foreign_key: "section_key", primary_key: "link_path"
    has_many :page_contents
    has_many :pages, through: :page_contents
    # , :uniq => true

    # Mobility translations with container backend (single JSONB column)
    # Fallbacks configured globally in mobility.rb initializer
    translates :raw

    def as_json(options = nil)
      super({only: [
               "key", "page_part_key", "visible_on_page"
             ],
             methods: admin_attribute_names
             }.merge(options || {}))
    end

    def admin_attribute_names
      # Returns locale-specific attribute names for serialization (replaces globalize_attribute_names)
      mobility_attribute_names + [:content_photos]
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
        # byebug
        CSV.foreach(file.path, headers: true) do |row|
          if row.to_hash["locale"].present? && row.to_hash["key"].present?
            # Translation.create! row.to_hash
            trsl = find_by_key(row["key"]) || new
            trsl.attributes = row.to_hash.slice("key", "value", "locale")
            # *accessible_attributes)
            trsl.save!
          end
        end
      end

      def to_csv(export_column_names = nil)
        # http://railscasts.com/episodes/362-exporting-csv-and-excel?view=asciicast
        # WARNING: This method exports ALL contents without tenant filtering.
        # Use to_csv_for_website instead for multi-tenant safety.
        export_column_names ||= column_names
        CSV.generate do |csv|
          csv << export_column_names
          all.each do |content|
            csv << content.attributes.values_at(*export_column_names)
          end
        end
      end

      # Multi-tenant safe CSV export - only exports contents for the specified website
      def to_csv_for_website(website, export_column_names = nil)
        export_column_names ||= column_names
        CSV.generate do |csv|
          csv << export_column_names
          where(website_id: website&.id).each do |content|
            csv << content.attributes.values_at(*export_column_names)
          end
        end
      end

      # Multi-tenant safe import - imports contents for the specified website
      def import_for_website(file, website)
        CSV.foreach(file.path, headers: true) do |row|
          if row.to_hash["key"].present?
            content = where(website_id: website&.id).find_by(key: row["key"]) || new(website_id: website&.id)
            content.attributes = row.to_hash.slice("key", "tag", "status", "sort_order")
            content.save!
          end
        end
      end
    end
    # def self.get_raw_by_key key
    #   content = Content.find_by_key(key)
    #   content ? content.raw : ""
    # end
  end
end
