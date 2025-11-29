module Pwb
  class Api::V1::WebContentResource < JSONAPI::Resource
    model_name 'Pwb::Content'
    attributes :key, :tag
    attributes :raw_fr, :raw_de, :raw_ru, :raw_pt
    attributes :raw_it, :raw_tr, :raw_nl, :raw_vi
    attributes :raw_ar, :raw_ca, :raw_pl, :raw_ro
    attributes :raw_es, :raw_en, :content_photos

    # /api/v1/web-contents?filter%5Btag%5D=home&filter%5Bkey%5D=tagLine
    # below is needed for above to work
    filters :tag, :key

    # Scope contents to current website for multi-tenancy
    def self.records(options = {})
      current_website = Pwb::Current.website
      if current_website
        current_website.contents
      else
        Pwb::Content.none
      end
    end
  end
end
