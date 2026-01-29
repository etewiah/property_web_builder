# frozen_string_literal: true

module ApiManage
  module V1
    # PagePartsController - Manage page part content (block_contents)
    #
    # This controller handles CRUD operations for PagePart records,
    # specifically the block_contents JSON that stores the actual
    # editable content for each page part.
    #
    # Endpoints:
    #   GET    /api_manage/v1/:locale/page_parts                    - List all page parts
    #   GET    /api_manage/v1/:locale/page_parts/:id                - Get page part by ID
    #   GET    /api_manage/v1/:locale/page_parts/by_key/:key        - Get page part by key
    #   POST   /api_manage/v1/:locale/page_parts/:id/regenerate     - Re-render pre-rendered HTML
    #
    # Deprecated (use /pages/:page_slug/page_parts/:page_part_key instead):
    #   PATCH  /api_manage/v1/:locale/page_parts/:id                - Update page part content
    #   PATCH  /api_manage/v1/:locale/page_parts/by_key/:key        - Update page part by key
    #
    class PagePartsController < BaseController
      before_action :set_page_part, only: %i[show regenerate]  # update removed (deprecated)
      before_action :set_page_part_by_key, only: %i[show_by_key]  # update_by_key removed (deprecated)

      # GET /api_manage/v1/:locale/page_parts
      # List all page parts for the current website
      def index
        page_parts = Pwb::PagePart.where(website_id: current_website&.id)
                                   .where(show_in_editor: true)
                                   .order(:page_slug, :page_part_key)

        # Optional filter by page_slug
        if params[:page_slug].present?
          page_parts = page_parts.where(page_slug: params[:page_slug])
        end

        render json: {
          page_parts: page_parts.map { |pp| page_part_summary(pp) }
        }
      end

      # GET /api_manage/v1/:locale/page_parts/:id
      def show
        render json: {
          page_part: page_part_details(@page_part)
        }
      end

      # GET /api_manage/v1/:locale/page_parts/by_key/:key
      # Key format: page_slug::page_part_key (e.g., "home::heroes/hero_centered")
      # Or just page_part_key for website-level parts
      def show_by_key
        render json: {
          page_part: page_part_details(@page_part)
        }
      end

      # PATCH /api_manage/v1/:locale/page_parts/:id
      # DEPRECATED: Use PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key instead
      # This endpoint has been removed from routes. Keeping method for reference.
      # Update block_contents for a specific locale
      def update
        locale = params[:locale] || I18n.locale.to_s

        if params[:block_contents].present?
          update_block_contents(@page_part, locale, params[:block_contents])
        end

        if @page_part.save
          # Optionally regenerate the pre-rendered HTML
          regenerate_content(@page_part, locale) if params[:regenerate] != false

          render json: {
            page_part: page_part_details(@page_part),
            message: 'Page part updated successfully'
          }
        else
          render json: {
            error: 'Validation failed',
            errors: @page_part.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # PATCH /api_manage/v1/:locale/page_parts/by_key/:key
      # DEPRECATED: Use PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key instead
      # This endpoint has been removed from routes. Keeping method for reference.
      def update_by_key
        locale = params[:locale] || I18n.locale.to_s

        if params[:block_contents].present?
          update_block_contents(@page_part, locale, params[:block_contents])
        end

        if @page_part.save
          regenerate_content(@page_part, locale) if params[:regenerate] != false

          render json: {
            page_part: page_part_details(@page_part),
            message: 'Page part updated successfully'
          }
        else
          render json: {
            error: 'Validation failed',
            errors: @page_part.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      # POST /api_manage/v1/:locale/page_parts/:id/regenerate
      # Re-render the pre-rendered HTML for all locales or specific locale
      def regenerate
        locale = params[:locale]
        locales = locale.present? ? [locale] : (@page_part.block_contents&.keys || [])

        locales.each do |loc|
          regenerate_content(@page_part, loc)
        end

        render json: {
          page_part: page_part_details(@page_part),
          message: "Pre-rendered HTML regenerated for #{locales.join(', ')}"
        }
      end

      private

      def set_page_part
        @page_part = Pwb::PagePart.where(website_id: current_website&.id).find(params[:id])
      end

      def set_page_part_by_key
        key = params[:key]

        # Parse key format: "page_slug::page_part_key" or just "page_part_key"
        if key.include?('::')
          page_slug, page_part_key = key.split('::', 2)
        else
          page_slug = nil
          page_part_key = key
        end

        # URL-decode the page_part_key (e.g., "heroes%2Fhero_centered" -> "heroes/hero_centered")
        page_part_key = CGI.unescape(page_part_key)

        @page_part = find_or_create_page_part(page_slug, page_part_key)
      end

      def find_or_create_page_part(page_slug, page_part_key)
        # Try to find existing
        scope = Pwb::PagePart.where(website_id: current_website&.id, page_part_key: page_part_key)

        if page_slug.present?
          page_part = scope.find_by(page_slug: page_slug)
        else
          page_part = scope.where(page_slug: [nil, '']).first
        end

        # Auto-create if not found
        unless page_part
          page_part = Pwb::PagePart.new(
            website_id: current_website.id,
            page_part_key: page_part_key,
            page_slug: page_slug,
            show_in_editor: true
          )
          initialize_from_library(page_part, page_part_key)
          page_part.save!
          Rails.logger.info "[ApiManage] Auto-created PagePart '#{page_part_key}' for page '#{page_slug}'"
        end

        page_part
      end

      def initialize_from_library(page_part, page_part_key)
        definition = Pwb::PagePartLibrary.definition(page_part_key)
        fields_config = definition&.dig(:fields)

        blocks = {}

        if fields_config.is_a?(Array)
          fields_config.each { |field_name| blocks[field_name.to_s] = { 'content' => '' } }
        elsif fields_config.is_a?(Hash)
          fields_config.each do |field_name, field_config|
            default_value = field_config[:default] || ''
            blocks[field_name.to_s] = { 'content' => default_value }
          end
        end

        default_locale = I18n.default_locale.to_s
        page_part.block_contents = { default_locale => { 'blocks' => blocks } }
      end

      def update_block_contents(page_part, locale, new_blocks)
        current = page_part.block_contents || {}
        current[locale] ||= { 'blocks' => {} }

        # Handle both direct blocks hash and wrapped { blocks: { ... } } format
        blocks_data = new_blocks.is_a?(ActionController::Parameters) ? new_blocks.to_unsafe_h : new_blocks
        blocks_data = blocks_data['blocks'] if blocks_data.is_a?(Hash) && blocks_data.key?('blocks')

        blocks_data.each do |field_name, field_data|
          current[locale]['blocks'] ||= {}

          if field_data.is_a?(Hash) && field_data.key?('content')
            current[locale]['blocks'][field_name.to_s] = { 'content' => field_data['content'] }
          else
            current[locale]['blocks'][field_name.to_s] = { 'content' => field_data.to_s }
          end
        end

        page_part.block_contents = current
      end

      def regenerate_content(page_part, locale)
        # Skip containers - they render dynamically
        return if Pwb::PagePartLibrary.container?(page_part.page_part_key)

        # Find associated PageContent records and regenerate their Content
        page_contents = Pwb::PageContent.where(
          website_id: current_website&.id,
          page_part_key: page_part.page_part_key
        )

        page_contents.each do |page_content|
          regenerate_page_content_html(page_content, page_part, locale)
        end
      end

      def regenerate_page_content_html(page_content, page_part, locale)
        # Get or create Content record
        content = page_content.content
        unless content
          content = Pwb::Content.create!(
            page_part_key: page_part.page_part_key,
            website_id: current_website.id
          )
          page_content.update!(content: content)
        end

        # Get template
        template_content = page_part.template_content
        if template_content.blank?
          template_path = Pwb::PagePartLibrary.template_path(page_part.page_part_key)
          template_content = File.read(template_path) if template_path && File.exist?(template_path)
        end
        return if template_content.blank?

        # Render Liquid template
        liquid_template = Liquid::Template.parse(template_content)
        blocks = page_part.block_contents.dig(locale, 'blocks') || {}
        rendered_html = liquid_template.render('page_part' => blocks)

        # Save to Content using Mobility's locale-specific setter
        content.send("raw_#{locale}=", rendered_html)
        content.save!
      rescue StandardError => e
        Rails.logger.error "[ApiManage] Failed to regenerate content for #{page_part.page_part_key}: #{e.message}"
      end

      def page_part_summary(page_part)
        {
          id: page_part.id,
          page_part_key: page_part.page_part_key,
          page_slug: page_part.page_slug,
          show_in_editor: page_part.show_in_editor,
          available_locales: page_part.block_contents&.keys || [],
          updated_at: page_part.updated_at&.iso8601
        }
      end

      def page_part_details(page_part)
        locale = params[:locale] || I18n.locale.to_s
        definition = Pwb::PagePartLibrary.definition(page_part.page_part_key)

        {
          id: page_part.id,
          page_part_key: page_part.page_part_key,
          page_slug: page_part.page_slug,
          show_in_editor: page_part.show_in_editor,

          # Content for the requested locale
          block_contents: page_part.block_contents&.dig(locale) || {},

          # All locales available
          available_locales: page_part.block_contents&.keys || [],

          # All block_contents (for multi-locale editing)
          all_locales_content: params[:include_all_locales] == 'true' ? page_part.block_contents : nil,

          # Field schema for editor UI
          field_schema: build_field_schema(page_part.page_part_key),

          # Definition metadata
          definition: definition ? {
            label: definition[:label],
            description: definition[:description],
            category: definition[:category],
            is_container: definition[:is_container] || false,
            slots: definition[:slots]
          } : nil,

          created_at: page_part.created_at&.iso8601,
          updated_at: page_part.updated_at&.iso8601
        }.compact
      end

      def build_field_schema(page_part_key)
        definition = Pwb::PagePartLibrary.definition(page_part_key)
        return nil unless definition

        fields_config = definition[:fields]
        return nil unless fields_config

        if fields_config.is_a?(Array)
          {
            'fields' => fields_config.map do |field_name|
              Pwb::FieldSchemaBuilder.build_field_definition(field_name, {})
            end,
            'groups' => []
          }
        else
          field_groups = definition[:field_groups] || {}
          {
            'fields' => fields_config.map do |field_name, field_config|
              Pwb::FieldSchemaBuilder.build_field_definition(field_name, field_config || {})
            end,
            'groups' => field_groups.map do |key, config|
              {
                'key' => key.to_s,
                'label' => config[:label] || key.to_s.humanize,
                'order' => config[:order] || 999
              }
            end.sort_by { |g| g['order'] }
          }
        end
      end
    end
  end
end
