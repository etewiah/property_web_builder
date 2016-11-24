module Pwb
  class Api::V1::WebContentResource < JSONAPI::Resource
    model_name 'Pwb::Content'
    attributes :key, :tag
    attributes :raw_es, :raw_en, :raw_ar, :content_photos

    # /api/v1/web-contents?filter%5Btag%5D=home&filter%5Bkey%5D=tagLine
    # below is needed for above to work
    filters :tag, :key
  end
end
