# frozen_string_literal: true

module ApiManage
  module V1
    # PagesController - Manage pages for the current website
    #
    # Endpoints:
    #   GET    /api_manage/v1/pages          - List all pages
    #   GET    /api_manage/v1/pages/:id      - Get page details
    #   PATCH  /api_manage/v1/pages/:id      - Update page settings
    #   PATCH  /api_manage/v1/pages/:id/reorder_parts - Reorder page parts
    #
    class PagesController < BaseController
      before_action :set_page, only: %i[show update reorder_parts]

      # GET /api_manage/v1/pages
      def index
        pages = Pwb::Page.where(website_id: current_website&.id)
                         .order(:sort_order_top_nav, :slug)

        render json: {
          pages: pages.map { |page| page_summary(page) }
        }
      end

      # GET /api_manage/v1/pages/:id
      def show
        render json: {
          page: page_details(@page)
        }
      end

      # PATCH /api_manage/v1/pages/:id
      def update
        if @page.update(page_params)
          render json: {
            page: page_details(@page),
            message: 'Page updated successfully'
          }
        else
          render json: {
            error: 'Validation failed',
            errors: @page.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api_manage/v1/pages/:id/reorder_parts
      def reorder_parts
        part_ids = params[:part_ids] || []

        part_ids.each_with_index do |part_id, index|
          page_part = @page.page_parts.find_by(id: part_id, website_id: current_website&.id)
          page_part&.update(order_in_editor: index)
        end

        render json: { message: 'Page parts reordered successfully' }
      end

      private

      def set_page
        @page = Pwb::Page.where(website_id: current_website&.id).find(params[:id])
      end

      def page_params
        params.require(:page).permit(
          :slug,
          :visible,
          :show_in_top_nav,
          :show_in_footer,
          :sort_order_top_nav,
          :sort_order_footer,
          :seo_title,
          :meta_description,
          :meta_keywords
        )
      end

      # Summary for list view
      def page_summary(page)
        {
          id: page.id,
          slug: page.slug,
          title: page.page_title || page.slug.titleize,
          visible: page.visible,
          show_in_top_nav: page.show_in_top_nav,
          show_in_footer: page.show_in_footer,
          sort_order_top_nav: page.sort_order_top_nav,
          sort_order_footer: page.sort_order_footer,
          updated_at: page.updated_at.iso8601
        }
      end

      # Full details for show/update
      def page_details(page)
        {
          id: page.id,
          slug: page.slug,
          title: page.page_title || page.slug.titleize,
          visible: page.visible,
          show_in_top_nav: page.show_in_top_nav,
          show_in_footer: page.show_in_footer,
          sort_order_top_nav: page.sort_order_top_nav,
          sort_order_footer: page.sort_order_footer,
          seo_title: page.seo_title,
          meta_description: page.meta_description,
          meta_keywords: page.meta_keywords,
          page_parts: page_parts_summary(page),
          created_at: page.created_at.iso8601,
          updated_at: page.updated_at.iso8601
        }
      end

      # Page parts for the page
      def page_parts_summary(page)
        page.page_parts
            .where(website_id: current_website&.id, show_in_editor: true)
            .order(:order_in_editor)
            .map do |part|
          {
            id: part.id,
            page_part_key: part.page_part_key,
            order_in_editor: part.order_in_editor,
            show_in_editor: part.show_in_editor
          }
        end
      end
    end
  end
end
