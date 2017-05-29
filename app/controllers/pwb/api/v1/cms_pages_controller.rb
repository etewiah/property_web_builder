module Pwb
  # http://localhost:3000/api/v1/cms-pages.json
  class Api::V1::CmsPagesController < JSONAPI::ResourceController
    # skip_before_action :verify_content_type_header
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    skip_before_action :ensure_valid_accept_media_type
    # skip_before_action :verify_accept_header


    def set_photo
      # This only creates a content photo
      # - does not associate it with a cms page yet
      photo = ContentPhoto.create
      # TODO - figure out how to remove orphaned photos
      if params[:file]
        photo.image = params[:file]
      end
      photo.save!
      photo.reload
      render json: photo.to_json
    end

    def meta
      @admin_setup = Pwb::CmsPageContainer.where(name: params[:page_name]).first || {}
      return render json: @admin_setup.as_json["attributes"]
    end

    def update
      updated_caches = []
      refresh_all_locales = false
      cms_pages_params[:attributes][:blocks].each do |block_params|
        block = Comfy::Cms::Block.find block_params[:id]
        if block_params[:is_image]
          # for images I want to update all language variants of the block
          cross_locale_blocks = Comfy::Cms::Block.where(identifier:  block_params[:identifier])
          cross_locale_blocks.each do |cross_locale_block|
            cross_locale_block.update block_params.slice :content
          end
          refresh_all_locales = true
        else
          block.update block_params.slice :content
        end
        # blocks.push block
      end

      if refresh_all_locales
        pages = Comfy::Cms::Page.where(label: cms_pages_params[:attributes][:label])
        pages.each do |page|
          page.clear_content_cache
          updated_caches.push({
            page_id: page.id,
            page_content_cache: page.content_cache
          })
        end
      else
        page = Comfy::Cms::Page.find cms_pages_params[:id]
        page.clear_content_cache
        # need to call content_cache again for refresh
        page.content_cache
      end

      # below ensures valid json_api response is sent:
      page = Comfy::Cms::Page.find cms_pages_params[:id]
      serialized_page = JSONAPI::ResourceSerializer.new(Pwb::Api::V1::CmsPageResource).serialize_to_hash(Pwb::Api::V1::CmsPageResource.new(page, nil))
      updated_caches.push {}
      serialized_page[:data]["attributes"]["updated-caches"] = updated_caches
      # [{id: 22, cc: "dddd"}]
      return render json: serialized_page
    end

    def cms_pages_params
      params.require(:data).permit(:id, :attributes => [ :label, :blocks => [ :content, :id, :identifier, :info, :is_image  ] ])
    end

  end
end
