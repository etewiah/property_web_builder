# frozen_string_literal: true

module SiteAdmin
  module Pages
    class PagePartsController < ::SiteAdminController
      before_action :set_page
      before_action :set_page_part

      def show
        @editor_setup = @page_part.editor_setup || {}
        @block_contents = @page_part.block_contents || {}
        @supported_locales = current_website.supported_locales.presence || ['en']
      end

      def edit
        @editor_setup = @page_part.editor_setup || {}
        @block_contents = @page_part.block_contents || {}
        @supported_locales = current_website.supported_locales.presence || ['en']
        @current_locale = params[:locale] || @supported_locales.first
      end

      def update
        locale = params[:locale] || 'en'
        block_contents = params[:block_contents] || {}

        # Build the fragment block structure expected by PagePartManager
        fragment_block = { 'blocks' => {} }
        block_contents.each do |label, content|
          fragment_block['blocks'][label] = { 'content' => content }
        end

        begin
          manager = Pwb::PagePartManager.new(@page_part.page_part_key, @page)
          result = manager.update_page_part_content(locale, fragment_block)

          respond_to do |format|
            format.html do
              redirect_to edit_site_admin_page_page_part_path(@page, @page_part, locale: locale),
                          notice: 'Page part updated successfully'
            end
            format.json { render json: { success: true, html: result[:fragment_html] } }
          end
        rescue StandardError => e
          respond_to do |format|
            format.html do
              flash.now[:alert] = "Failed to update: #{e.message}"
              @editor_setup = @page_part.editor_setup || {}
              @block_contents = @page_part.block_contents || {}
              @supported_locales = current_website.supported_locales.presence || ['en']
              @current_locale = locale
              render :edit, status: :unprocessable_entity
            end
            format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
          end
        end
      end

      def toggle_visibility
        visible = params[:visible] == 'true'
        @page.set_fragment_visibility(@page_part.page_part_key, visible)

        redirect_to site_admin_page_path(@page),
                    notice: "Page part visibility updated to #{visible ? 'visible' : 'hidden'}"
      end

      private

      def set_page
        @page = Pwb::Page.where(website_id: current_website&.id).find(params[:page_id])
      end

      def set_page_part
        @page_part = @page.page_parts.where(website_id: current_website&.id).find(params[:id])
      end
    end
  end
end
