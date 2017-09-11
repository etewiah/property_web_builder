module Pwb
  class Api::V1::CmsPageResource < JSONAPI::Resource
    # model_name 'Comfy::Cms::Page'
    # # model_hint model: Pwb::Prop, resource: :lite_properties

    # attributes :label, :slug, :full_path,
    #   :blocks, :tags, :categories,
    #   :locale, :content_cache, 
    #   # below 3 are not used in admin panel
    #   # but need to be populated when creating new page
    #   :site_id, :layout_id, :parent_id

    # filters :label, :full_path
    # has_many :cms_blocks

    # # TODO - add locale col to Cms::Page
    # def locale
    #   # return @model.site.locale
    #   return @model.slug
    # end


    # def self.creatable_fields(context)
    #   super - [:locale]
    # end
  end
end
