# frozen_string_literal: true

module SiteAdmin
  # PagesController
  # Manages pages for the current website
  class PagesController < SiteAdminController
    before_action :set_page, only: %i[show edit settings update_settings reorder_parts]

    def index
      # Scope to current website for multi-tenant isolation
      pages = Pwb::Page.where(website_id: current_website&.id).order(created_at: :desc)

      # Search functionality
      if params[:search].present?
        pages = pages.where('slug ILIKE ?', "%#{params[:search]}%")
      end

      @pagy, @pages = pagy(pages, limit: 25)
    end

    def show
      # @page set by before_action
    end

    # New edit action - shows page parts with drag-drop, previews, visibility toggles
    def edit
      @page_parts = @page.page_parts
                         .where(website_id: current_website&.id, show_in_editor: true)
                         .order(:order_in_editor)
    end

    # Settings action - page metadata (slug, navigation visibility)
    def settings
      # @page set by before_action
    end

    def update_settings
      if @page.update(page_params)
        redirect_to settings_site_admin_page_path(@page), notice: 'Page settings were successfully updated.'
      else
        render :settings
      end
    end

    # Reorder page parts via drag-drop
    def reorder_parts
      part_ids = params[:part_ids] || []

      part_ids.each_with_index do |part_id, index|
        page_part = @page.page_parts.find_by(id: part_id, website_id: current_website&.id)
        page_part&.update(order_in_editor: index)
      end

      head :ok
    end

    private

    def set_page
      @page = Pwb::Page.where(website_id: current_website&.id).find(params[:id])
    end

    def page_params
      params.require(:pwb_page).permit(:slug, :visible, :show_in_top_nav, :show_in_footer, :sort_order_top_nav, :sort_order_footer)
    end
  end
end
