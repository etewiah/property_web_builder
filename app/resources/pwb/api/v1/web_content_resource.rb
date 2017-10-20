module Pwb
  class Api::V1::WebContentResource < JSONAPI::Resource
    model_name 'Pwb::Content'
    attributes :key, :tag
    attributes :raw_fr, :raw_de, :raw_ru, :raw_pt
    attributes :raw_es, :raw_en, :content_photos

    # /api/v1/web-contents?filter%5Btag%5D=home&filter%5Bkey%5D=tagLine
    # below is needed for above to work
    filters :tag, :key
  end
end
