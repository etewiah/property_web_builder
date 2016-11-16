module Pwb
  class Content < ApplicationRecord
    has_many :content_photos, dependent: :destroy

    translates :raw, :fallbacks_for_empty_translations => true
    globalize_accessors :locales => [:en, :ca, :es, :fr, :ar]


    def default_photo_url
      if self.content_photos.first
        return self.content_photos.first.image_url
      else
        # return "/images/prv/estate/item-3.jpg"
        return "https://placeholdit.imgix.net/~text?txtsize=38&txt=&w=550&h=300&txttrack=0"
      end
    end

  end
end
