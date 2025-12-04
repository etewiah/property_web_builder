# frozen_string_literal: true

module SiteAdmin
  # PagesController
  # Manages pages for the current website
  class PagesController < SiteAdminController
    def index
      @pages = Pwb::Page.order(created_at: :desc)

      # Search functionality
      if params[:search].present?
        @pages = @pages.where('slug ILIKE ?', "%#{params[:search]}%")
      end
    end

    def show
      @page = Pwb::Page.find(params[:id])
    end

    def edit
      @page = Pwb::Page.find(params[:id])
    end

    def update
      @page = Pwb::Page.find(params[:id])
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
