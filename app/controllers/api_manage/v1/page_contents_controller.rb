# frozen_string_literal: true

module ApiManage
  module V1
    # PageContentsController - Manage page content placements and containers
    #
    # Endpoints:
    #   GET    /api_manage/v1/:locale/pages/:page_id/page_contents     - List page contents
    #   POST   /api_manage/v1/:locale/pages/:page_id/page_contents     - Create page content
    #   GET    /api_manage/v1/:locale/page_contents/:id                - Get page content details
    #   PATCH  /api_manage/v1/:locale/page_contents/:id                - Update page content
    #   DELETE /api_manage/v1/:locale/page_contents/:id                - Delete page content
    #   PATCH  /api_manage/v1/:locale/pages/:page_id/page_contents/reorder - Reorder page contents
    #
    class PageContentsController < BaseController
      before_action :set_page, only: %i[index create reorder]
      before_action :set_page_content, only: %i[show update destroy]

      # GET /api_manage/v1/:locale/pages/:page_id/page_contents
      def index
        page_contents = @page.page_contents
                             .root_level
                             .ordered_visible
                             .includes(:content, :child_page_contents)

        render json: {
          page_contents: page_contents.map { |pc| page_content_json(pc, include_children: true) }
        }
      end

      # GET /api_manage/v1/:locale/page_contents/:id
      def show
        render json: {
          page_content: page_content_json(@page_content, include_children: true)
        }
      end

      # POST /api_manage/v1/:locale/pages/:page_id/page_contents
      def create
        @page_content = @page.page_contents.build(page_content_params)
        @page_content.website_id = current_website.id

        # Validate container assignment
        if @page_content.parent_page_content_id.present?
          parent = Pwb::PageContent.find_by(id: @page_content.parent_page_content_id)
          unless parent&.container?
            return render json: {
              error: 'Invalid parent',
              message: 'Parent page content must be a container'
            }, status: :unprocessable_entity
          end
        end

        if @page_content.save
          render json: {
            page_content: page_content_json(@page_content),
            message: 'Page content created successfully'
          }, status: :created
        else
          render json: {
            error: 'Validation failed',
            errors: @page_content.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api_manage/v1/:locale/page_contents/:id
      def update
        if @page_content.update(page_content_update_params)
          render json: {
            page_content: page_content_json(@page_content, include_children: true),
            message: 'Page content updated successfully'
          }
        else
          render json: {
            error: 'Validation failed',
            errors: @page_content.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api_manage/v1/:locale/page_contents/:id
      def destroy
        # Check if this is a container with children
        if @page_content.container? && @page_content.child_page_contents.exists?
          return render json: {
            error: 'Cannot delete',
            message: 'Container has children. Remove children first or use force=true to delete all.',
            children_count: @page_content.child_page_contents.count
          }, status: :unprocessable_entity
        end

        @page_content.destroy!
        render json: { message: 'Page content deleted successfully' }
      end

      # PATCH /api_manage/v1/:locale/pages/:page_id/page_contents/reorder
      # Params:
      #   - order: Array of { id: page_content_id, sort_order: number }
      #   - slot_order: Hash of { slot_name: [array of page_content_ids] } (for container children)
      def reorder
        ActiveRecord::Base.transaction do
          # Reorder root-level page contents
          if params[:order].present?
            params[:order].each do |item|
              pc = @page.page_contents.find_by(id: item[:id])
              pc&.update!(sort_order: item[:sort_order])
            end
          end

          # Reorder children within container slots
          if params[:slot_order].present? && params[:container_id].present?
            container = @page.page_contents.find(params[:container_id])

            params[:slot_order].each do |slot_name, ids|
              ids.each_with_index do |id, index|
                child = container.child_page_contents.find_by(id: id)
                child&.update!(slot_name: slot_name, sort_order: index)
              end
            end
          end
        end

        render json: { message: 'Page contents reordered successfully' }
      rescue ActiveRecord::RecordInvalid => e
        render json: {
          error: 'Reorder failed',
          errors: e.record.errors.full_messages
        }, status: :unprocessable_entity
      end

      private

      def set_page
        @page = Pwb::Page.where(website_id: current_website&.id).find(params[:page_id])
      end

      def set_page_content
        @page_content = Pwb::PageContent.where(website_id: current_website&.id).find(params[:id])
      end

      def page_content_params
        params.require(:page_content).permit(
          :page_part_key,
          :sort_order,
          :visible_on_page,
          :label,
          :parent_page_content_id,
          :slot_name
        )
      end

      def page_content_update_params
        params.require(:page_content).permit(
          :sort_order,
          :visible_on_page,
          :label,
          :slot_name
        )
      end

      # Build JSON representation of a page content
      def page_content_json(page_content, include_children: false)
        definition = Pwb::PagePartLibrary.definition(page_content.page_part_key)

        json = {
          id: page_content.id,
          page_part_key: page_content.page_part_key,
          sort_order: page_content.sort_order,
          visible_on_page: page_content.visible_on_page,
          is_rails_part: page_content.is_rails_part,
          label: page_content.label,
          is_container: page_content.container?,
          parent_page_content_id: page_content.parent_page_content_id,
          slot_name: page_content.slot_name,
          # Include definition metadata for UI
          definition: definition ? {
            label: definition[:label],
            description: definition[:description],
            category: definition[:category],
            is_container: definition[:is_container],
            slots: definition[:slots]
          } : nil,
          created_at: page_content.created_at&.iso8601,
          updated_at: page_content.updated_at&.iso8601
        }

        # Include children for containers
        if include_children && page_content.container?
          json[:slots] = {}
          page_content.available_slots.each do |slot_name|
            children = page_content.children_in_slot(slot_name)
            json[:slots][slot_name] = children.map { |child| page_content_json(child) }
          end
        end

        json
      end
    end
  end
end
