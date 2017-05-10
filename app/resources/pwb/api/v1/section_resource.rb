module Pwb
  class Api::V1::SectionResource < JSONAPI::Resource
    model_name 'Pwb::Section'
    attributes :link_key, :link_path, :visible, :sort_order, :id
    # attributes :link_title_es, :link_title_en, :link_title_ar
    # attributes :page_title_es, :page_title_en, :page_title_ar
    # attributes :show_in_top_nav, :show_in_footer, :is_page
    # attributes :key, :contents


    # http://tenant1.tee.dev:3000/api/v1/web-contents?filter%5Blang_code%5D=en&filter%5Bkey%5D=tagLine
    # below is needed for above to work
    # filters :lang_code, :key
  end
end
