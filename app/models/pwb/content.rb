module Pwb
  class Content < ApplicationRecord
    belongs_to :website, optional: true
    has_many :content_photos, dependent: :destroy
    # belongs_to :section, optional: true, foreign_key: "section_key", primary_key: "link_path"
    has_many :page_contents
    has_many :pages, through: :page_contents
    # , :uniq => true

    translates :raw, fallbacks_for_empty_translations: true
    globalize_accessors locales: I18n.available_locales
    # globalize_accessors locales: [:en, :ca, :es, :fr, :ar, :de, :ru, :pt]

    attribute :raw

    def as_json(options = nil)
      super({only: [
               "key", "page_part_key", "visible_on_page"
             ],
             methods: admin_attribute_names
             }.merge(options || {}))
    end

    def admin_attribute_names
      globalize_attribute_names.push :content_photos
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
        export_column_names ||= column_names
        CSV.generate do |csv|
          csv << export_column_names
          all.each do |content|
            csv << content.attributes.values_at(*export_column_names)
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
