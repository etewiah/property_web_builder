# frozen_string_literal: true

module SiteAdmin
  # PagesController
  # Manages pages for the current website
  class PagesController < SiteAdminController
    def index
      # Scope to current website for multi-tenant isolation
      @pages = Pwb::Page.where(website_id: current_website&.id).order(created_at: :desc)

      # Search functionality
      if params[:search].present?
        @pages = @pages.where('slug ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      # Scope to current website for security
      @page = Pwb::Page.where(website_id: current_website&.id).find(params[:id])
    end

    def edit
      # Scope to current website for security
      @page = Pwb::Page.where(website_id: current_website&.id).find(params[:id])
    end

    def update
      # Scope to current website for security
      @page = Pwb::Page.where(website_id: current_website&.id).find(params[:id])
      if @page.update(page_params)
        redirect_to site_admin_page_path(@page), notice: 'Page was successfully updated.'
      else
        render :edit
      end
    end

    private

    def page_params
      params.require(:pwb_page).permit(:slug, :visible, :show_in_top_nav, :show_in_footer, :sort_order_top_nav, :sort_order_footer)
    end
  end
end
