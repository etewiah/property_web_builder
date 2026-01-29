module Pwb
  class Editor::PagePartsController < ApplicationController
    layout false
    # Skip theme path setup since we return JSON/partials
    skip_before_action :set_theme_path
    skip_before_action :nav_links
    skip_before_action :footer_content
    # Skip CSRF for API calls (forms include their own token)
    skip_before_action :verify_authenticity_token, only: [:update]
    # TODO: Re-enable authentication before production
    # before_action :authenticate_admin_user!
    before_action :set_page_part, only: [:show, :update]
    
    # Handle record not found gracefully
    rescue_from ActiveRecord::RecordNotFound, with: :page_part_not_found

    def show
      # Allow specifying which locale to edit (defaults to current I18n locale)
      @editing_locale = params[:editing_locale].presence || I18n.locale.to_s
      render partial: "form", locals: { page_part: @page_part, editing_locale: @editing_locale }
    end

    def update
      # Transform content params to block_contents structure
      # Params structure: page_part[content][locale][blocks][block_name][content]
      if params[:page_part] && params[:page_part][:content]
        new_content = params[:page_part][:content].to_unsafe_h
        
        # Deep merge with existing block_contents to preserve structure
        current_blocks = @page_part.block_contents || {}
        
        new_content.each do |locale, locale_data|
          current_blocks[locale] ||= {}
          
          if locale_data.is_a?(Hash) && locale_data["blocks"]
            current_blocks[locale]["blocks"] ||= {}
            
            locale_data["blocks"].each do |block_name, block_data|
              current_blocks[locale]["blocks"][block_name] ||= {}
              if block_data.is_a?(Hash) && block_data.key?("content")
                current_blocks[locale]["blocks"][block_name]["content"] = block_data["content"]
              end
            end
          end
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
      page_part_key = params[:id]

      # Strictly require website_id to be set for multi-tenant isolation
      return page_part_not_found unless @current_website&.id

      # Find existing or create new PagePart for this website
      @page_part = PagePart.find_or_initialize_by(
        website_id: @current_website.id,
        page_part_key: page_part_key
      )

      # If new record, initialize with fields from PagePartLibrary
      if @page_part.new_record?
        initialize_page_part_from_library(page_part_key)
        @page_part.save!
        Rails.logger.info "[Editor] Auto-created PagePart '#{page_part_key}' for website #{@current_website.id}"
      end
    end

    # Initialize a new PagePart with default block_contents from PagePartLibrary
    def initialize_page_part_from_library(page_part_key)
      definition = Pwb::PagePartLibrary.definition(page_part_key)
      fields_config = definition&.dig(:fields)

      blocks = {}

      # Handle both array (legacy) and hash (modern) field definitions
      if fields_config.is_a?(Array)
        fields_config.each { |field_name| blocks[field_name.to_s] = { 'content' => '' } }
      elsif fields_config.is_a?(Hash)
        fields_config.each do |field_name, field_config|
          default_value = field_config[:default] || ''
          blocks[field_name.to_s] = { 'content' => default_value }
        end
      end

      # Initialize for default locale
      default_locale = I18n.default_locale.to_s
      @page_part.block_contents = {
        default_locale => { 'blocks' => blocks }
      }

      @page_part.show_in_editor = true
    end

    def page_part_not_found(exception = nil)
      page_part_key = params[:id]

      # Log the error for debugging
      if exception
        Rails.logger.warn "[Editor] PagePart error for '#{page_part_key}': #{exception.message}"
      else
        Rails.logger.warn "[Editor] PagePart not found: '#{page_part_key}' (no website context)"
      end

      error_html = <<~HTML
        <div class="pwb-editor-error">
          <div class="pwb-error-icon"><i class="fas fa-exclamation-triangle"></i></div>
          <h4>Content Not Available</h4>
          <p>The content block "<strong>#{ERB::Util.html_escape(page_part_key)}</strong>" could not be loaded.</p>
          <p class="pwb-error-hint">This may happen if the website context is not available. Please try refreshing the page.</p>
        </div>
        <style>
          .pwb-editor-error {
            text-align: center;
            padding: 2rem;
            color: #94a3b8;
          }
          .pwb-error-icon {
            font-size: 2.5rem;
            color: #f59e0b;
            margin-bottom: 1rem;
          }
          .pwb-editor-error h4 {
            color: #e2e8f0;
            margin: 0 0 0.5rem 0;
          }
          .pwb-editor-error p {
            margin: 0.5rem 0;
            font-size: 0.9rem;
          }
          .pwb-error-hint {
            color: #64748b;
            font-size: 0.85rem;
          }
        </style>
      HTML
      render html: error_html.html_safe, status: :ok
    end

    def page_part_params
      params.require(:page_part).permit(:template)
    end

    def authenticate_admin_user!
      unless current_user && current_user.admin_for?(@current_website)
        render json: { error: "Unauthorized" }, status: :unauthorized
      end
    end
  end
end
