# frozen_string_literal: true

module ApiManage
  module V1
    # Reorder page parts on a specific page using semantic identifiers
    #
    # This endpoint allows reordering page parts using page_slug and page_part_keys
    # rather than internal IDs.
    #
    # PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/reorder
    # Body: { "order": ["heroes/hero_centered", "cta/cta_banner", "features/feature_grid"] }
    #
    # Replaces:
    #   - PATCH /api_manage/v1/:locale/pages/:page_id/page_contents/reorder (deprecated)
    #   - PATCH /api_manage/v1/:locale/pages/:id/reorder_parts (deprecated)
    #
    class PagePartReorderController < BaseController
      before_action :set_page

      # PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/reorder
      def update
        order = params[:order]

        if order.blank? || !order.is_a?(Array)
          return render json: {
            error: 'Missing parameter',
            message: "Required parameter 'order' must be an array of page_part_keys"
          }, status: :bad_request
        end

        # Validate all page_part_keys exist on this page
        existing_keys = @page.page_contents.pluck(:page_part_key)
        unknown_keys = order - existing_keys

        if unknown_keys.any?
          return render json: {
            error: 'Invalid page part keys',
            message: "The following page_part_keys were not found on this page: #{unknown_keys.join(', ')}",
            code: 'PAGE_PARTS_NOT_FOUND',
            unknown_keys: unknown_keys,
            available_keys: existing_keys
          }, status: :unprocessable_entity
        end

        # Update sort_order for each page content based on position in array
        ActiveRecord::Base.transaction do
          order.each_with_index do |page_part_key, index|
            page_content = @page.page_contents.find_by(page_part_key: page_part_key)
            page_content&.update!(sort_order: index)
          end
        end

        # Return the new order
        render json: {
          page_slug: @page.slug,
          order: @page.page_contents.order(:sort_order).pluck(:page_part_key),
          message: 'Page parts reordered successfully'
        }
      rescue ActiveRecord::RecordInvalid => e
        render json: {
          error: 'Reorder failed',
          message: e.record.errors.full_messages.join(', ')
        }, status: :unprocessable_entity
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
    end
  end
end
