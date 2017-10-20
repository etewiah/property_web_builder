module Pwb
  # grew out of Api::V1::CmsPagesController which had used
  # comfy mex sofa
  class Api::V1::PageFragmentsController < ApplicationApiController
    def show
      page = Page.find_by_slug "home"
      render json: page.details["fragments"]      
    end

    def update
      page = Page.find_by_slug "home"

      services_fragment = {
        "about_us_services": {
          "en": cms_page_update_params[:attributes]
        }
      }
      page.details["fragments"] = services_fragment.as_json

      # page.update(page_params)
      page.save!
      render json: page.details["fragments"]      


      # updated_caches = []
      # refresh_all_locales = false
      # cms_page_update_params[:attributes][:blocks].each do |block_params|
      #   block = Comfy::Cms::Block.find block_params[:id]
      #   if block_params[:is_image]
      #     # for images I want to update all language variants of the block
      #     cross_locale_blocks = Comfy::Cms::Block.where(identifier: block_params[:identifier])
      #     cross_locale_blocks.each do |cross_locale_block|
      #       cross_locale_block.update block_params.slice :content
      #     end
      #     refresh_all_locales = true
      #   else
      #     block.update block_params.slice :content
      #   end
      #   # blocks.push block
      # end

      # if refresh_all_locales
      #   pages = Comfy::Cms::Page.where(label: cms_page_update_params[:attributes][:label])
      #   pages.each do |page|
      #     page.clear_content_cache
      #     updated_caches.push({
      #                           page_id: page.id,
      #                           page_content_cache: page.content_cache
      #     })
      #   end
      # else
      #   page = Comfy::Cms::Page.find cms_page_update_params[:id]
      #   page.clear_content_cache
      #   # need to call content_cache again for refresh
      #   page.content_cache
      # end

      # # below ensures valid json_api response is sent:
      # page = Comfy::Cms::Page.find cms_page_update_params[:id]
      # serialized_page = JSONAPI::ResourceSerializer.new(Pwb::Api::V1::CmsPageResource).serialize_to_hash(Pwb::Api::V1::CmsPageResource.new(page, nil))
      # updated_caches.push {}
      # serialized_page[:data]["attributes"]["updated-caches"] = updated_caches
      # # [{id: 22, cc: "dddd"}]
      # render json: serialized_page

      # render json: page
    end


    def cms_page_update_params
      params.require(:data).permit(:id, attributes: [:label, blocks: [:content, :id, :identifier, :info, :is_image]])
    end
  end
end
