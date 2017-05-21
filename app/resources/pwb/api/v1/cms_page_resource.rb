module Pwb
  class Api::V1::CmsPageResource < JSONAPI::Resource
    model_name 'Comfy::Cms::Page'
    # model_hint model: Pwb::Prop, resource: :lite_properties

    attributes :label, :slug, :full_path,
      :blocks, :tags, :categories,
      :locale, :content_cache

    filters :label, :full_path
    has_many :cms_blocks

    def locale
      # return @model.site.locale
      return @model.slug
    end

  end
end
