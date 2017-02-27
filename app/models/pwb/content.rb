module Pwb
  class Content < ApplicationRecord
    has_many :content_photos, dependent: :destroy

    translates :raw, fallbacks_for_empty_translations: true
    globalize_accessors locales: [:en, :ca, :es, :fr, :ar]

    def default_photo_url
      if content_photos.first
        content_photos.first.image_url
      else
        'https://placeholdit.imgix.net/~text?txtsize=38&txt=&w=550&h=300&txttrack=0'
      end
    end

    class << self
      def to_csv export_column_names=nil
        # http://railscasts.com/episodes/362-exporting-csv-and-excel?view=asciicast
        export_column_names = export_column_names || column_names
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
