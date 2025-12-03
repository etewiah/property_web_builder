module Pwb
  class Editor::PagePartsController < ApplicationController
    layout false
    # TODO: Re-enable authentication before production
    # before_action :authenticate_admin_user!
    before_action :set_page_part, only: [:show, :update]

    def show
      render partial: "form", locals: { page_part: @page_part }
    end

    def update
      # Transform content params to block_contents structure
      if params[:page_part] && params[:page_part][:content]
        new_content = params[:page_part][:content].to_unsafe_h
        
        # Merge with existing block_contents to preserve structure
        current_blocks = @page_part.block_contents || {}
        
        new_content.each do |key, value|
          current_blocks[key] ||= {}
          current_blocks[key]["content"] = value
        end
        
        @page_part.block_contents = current_blocks
      end

      if @page_part.save
        render json: { status: "success", content: @page_part.block_contents }
      else
        render json: { status: "error", errors: @page_part.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def set_page_part
      @page_part = PagePart.find_by_page_part_key!(params[:id])
    end

    def page_part_params
      params.require(:page_part).permit(:template)
    end

    def authenticate_admin_user!
      unless current_user && current_user.admin?
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
