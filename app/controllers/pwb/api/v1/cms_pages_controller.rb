module Pwb
  # http://localhost:3000/api/v1/cms-pages.json
  class Api::V1::CmsPagesController < JSONAPI::ResourceController
    # skip_before_action :verify_content_type_header
    # Skipping action below allows me to browse to endpoint
    # without having set mime type
    skip_before_action :ensure_valid_accept_media_type
    # skip_before_action :verify_accept_header

    def update
      blocks = []
      cms_pages_params[:attributes][:blocks].each do |block_params|
        block = Comfy::Cms::Block.find block_params[:id]
        block.update block_params.slice :content
        blocks.push block
      end
      page = Comfy::Cms::Page.find cms_pages_params[:id]
      page.clear_content_cache
      # byebug - might need to call content_cache again for refresh
      # should also return valid json_api here
      render json: blocks.as_json
    end

    def cms_pages_params
     params.require(:data).permit(:id, :attributes => [ :blocks => [ :content, :id ] ])
    end

  end
end
