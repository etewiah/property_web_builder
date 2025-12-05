# frozen_string_literal: true

module SiteAdmin
  module Pages
    class PagePartsController < ::SiteAdminController
      include LocaleHelper

      before_action :set_page
      before_action :set_page_part
      before_action :set_locale_details

      def show
        @editor_setup = @page_part.editor_setup || {}
        @block_contents = @page_part.block_contents || {}
      end

      def edit
        @editor_setup = @page_part.editor_setup || {}
        @block_contents = @page_part.block_contents || {}
      end

      def update
        block_contents = params[:block_contents] || {}

        # Build the fragment block structure expected by PagePartManager
        fragment_block = { 'blocks' => {} }
        block_contents.each do |label, content|
          fragment_block['blocks'][label] = { 'content' => content }
        end

        begin
          manager = Pwb::PagePartManager.new(@page_part.page_part_key, @page)
          # Use base locale for content storage (e.g., "en" not "en-UK")
          result = manager.update_page_part_content(@current_locale_base, fragment_block)

          respond_to do |format|
            format.html do
              redirect_to edit_site_admin_page_page_part_path(@page, @page_part, locale: @current_locale_full),
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

      # Sets up locale-related instance variables for views and actions.
      # Handles the conversion between full locales (en-UK) and base locales (en).
      #
      # Instance variables set:
      # - @locale_details: Array of locale info hashes with :full, :base, and :label keys
      # - @current_locale_full: The full locale code from params or default (e.g., "en-UK")
      # - @current_locale_base: The base locale for content access (e.g., "en")
      #
      def set_locale_details
        supported = current_website.supported_locales.presence || ['en']
        @locale_details = build_locale_details(supported)

        # Determine current locale from params, defaulting to first supported
        @current_locale_full = params[:locale].presence || supported.first || 'en'

        # Convert to base locale for content access (en-UK -> en)
        @current_locale_base = locale_to_base(@current_locale_full)

        # Find the matching locale detail for current locale
        @current_locale_detail = @locale_details.find { |d| d[:full] == @current_locale_full } ||
                                 @locale_details.find { |d| d[:base] == @current_locale_base } ||
                                 @locale_details.first
      end
    end
  end
end
