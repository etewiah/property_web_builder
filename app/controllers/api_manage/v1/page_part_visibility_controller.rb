# frozen_string_literal: true

module ApiManage
  module V1
    # Toggle visibility of a page part on a specific page
    #
    # This endpoint allows toggling whether a page part is visible on a page,
    # using semantic identifiers (page_slug + page_part_key) rather than internal IDs.
    #
    # PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key/visibility
    # Body: { "visible": true/false }
    #
    class PagePartVisibilityController < BaseController
      before_action :set_page
      before_action :set_page_content

      # PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key/visibility
      def update
        visible = params[:visible]

        if visible.nil?
          return render json: {
            error: 'Missing parameter',
            message: "Required parameter 'visible' (true/false) is missing"
          }, status: :bad_request
        end

        # Convert string "true"/"false" to boolean if needed
        visible_bool = ActiveModel::Type::Boolean.new.cast(visible)

        if @page_content.update(visible_on_page: visible_bool)
          render json: {
            page_slug: @page.slug,
            page_part_key: @page_content.page_part_key,
            visible: @page_content.visible_on_page,
            message: "Visibility updated successfully"
          }
        else
          render json: {
            error: 'Update failed',
            errors: @page_content.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def set_page
        @page = Pwb::Page.find_by!(
          website_id: current_website.id,
          slug: params[:page_slug]
        )
      rescue ActiveRecord::RecordNotFound
        render json: {
          error: 'Page not found',
          message: "No page found with slug '#{params[:page_slug]}'",
          code: 'PAGE_NOT_FOUND'
        }, status: :not_found
      end

      def set_page_content
        return unless @page

        @page_content = @page.page_contents.find_by(page_part_key: params[:page_part_key])

        unless @page_content
          render json: {
            error: 'Page part not found',
            message: "No page part '#{params[:page_part_key]}' found on page '#{params[:page_slug]}'",
            code: 'PAGE_PART_NOT_FOUND',
            available_parts: @page.page_contents.pluck(:page_part_key)
          }, status: :not_found
        end
      end
    end
  end
end
