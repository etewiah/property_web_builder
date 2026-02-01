# frozen_string_literal: true

module ApiManage
  module V1
    # Update page part content using semantic identifiers
    #
    # This endpoint allows updating page part content (block_contents and rendered_html)
    # using page_slug and page_part_key rather than internal IDs.
    #
    # PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key
    #
    # Body:
    #   {
    #     "block_contents": { "field_name": { "content": "value" } },
    #     "rendered_html": "<section>...</section>"  # REQUIRED
    #   }
    #
    # The rendered_html is saved directly without server-side Liquid rendering.
    # To force server-side regeneration, pass "regenerate": true
    #
    class PagePartContentController < BaseController
      before_action :set_page
      before_action :set_page_part

      # PATCH /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key
      def update
        locale = params[:locale] || I18n.locale.to_s

        # rendered_html is required unless regenerate is explicitly true
        if params[:rendered_html].blank? && params[:regenerate] != true && params[:regenerate] != 'true'
          return render json: {
            error: 'Missing parameter',
            message: "Required parameter 'rendered_html' is missing. Provide rendered HTML or set 'regenerate': true to use server-side rendering."
          }, status: :bad_request
        end

        # Update block_contents if provided
        if params[:block_contents].present?
          update_block_contents(@page_part, locale, params[:block_contents])
        end

        unless @page_part.save
          return render json: {
            error: 'Validation failed',
            errors: @page_part.errors.full_messages
          }, status: :unprocessable_entity
        end

        # Handle HTML: use provided or regenerate
        if params[:regenerate] == true || params[:regenerate] == 'true'
          regenerate_content(@page_part, locale)
        elsif params[:rendered_html].present?
          save_rendered_html(@page_part, locale, params[:rendered_html])
        end

        render json: {
          page_slug: @page.slug,
          page_part_key: @page_part.page_part_key,
          locale: locale,
          block_contents: @page_part.block_contents&.dig(locale) || {},
          message: 'Page part content updated successfully'
        }
      end

      # GET /api_manage/v1/:locale/pages/:page_slug/page_parts/:page_part_key
      def show
        locale = params[:locale] || I18n.locale.to_s

        render json: {
          page_slug: @page.slug,
          page_part_key: @page_part.page_part_key,
          locale: locale,
          block_contents: @page_part.block_contents&.dig(locale) || {},
          available_locales: @page_part.block_contents&.keys || [],
          field_schema: build_field_schema(@page_part.page_part_key),
          updated_at: @page_part.updated_at&.iso8601
        }
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

      def set_page_part
        return unless @page

        page_part_key = params[:page_part_key]

        # Find existing or create new PagePart
        @page_part = Pwb::PagePart.find_by(
          website_id: current_website.id,
          page_part_key: page_part_key,
          page_slug: @page.slug
        )

        # Fall back to website-wide PagePart
        @page_part ||= Pwb::PagePart.where(website_id: current_website.id, page_part_key: page_part_key)
                                     .where(page_slug: [nil, ''])
                                     .first

        # Auto-create if not found
        unless @page_part
          @page_part = Pwb::PagePart.new(
            website_id: current_website.id,
            page_part_key: page_part_key,
            page_slug: @page.slug,
            show_in_editor: true
          )
          initialize_from_library(@page_part, page_part_key)
          @page_part.save!
          Rails.logger.info "[PagePartContent] Auto-created PagePart '#{page_part_key}' for page '#{@page.slug}'"
        end
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

      def save_rendered_html(page_part, locale, rendered_html)
        # Find associated PageContent records and update their Content
        page_contents = Pwb::PageContent.where(
          website_id: current_website.id,
          page_part_key: page_part.page_part_key,
          page_id: @page.id
        )

        page_contents.each do |page_content|
          content = page_content.content
          unless content
            content = Pwb::Content.create!(
              page_part_key: page_part.page_part_key,
              website_id: current_website.id
            )
            page_content.update!(content: content)
          end

          # Save using Mobility's locale-specific setter
          content.send("raw_#{locale}=", rendered_html)
          content.save!
        end
      end

      def regenerate_content(page_part, locale)
        # Skip containers - they render dynamically
        return if Pwb::PagePartLibrary.container?(page_part.page_part_key)

        page_contents = Pwb::PageContent.where(
          website_id: current_website.id,
          page_part_key: page_part.page_part_key,
          page_id: @page.id
        )

        page_contents.each do |page_content|
          regenerate_page_content_html(page_content, page_part, locale)
        end
      end

      def regenerate_page_content_html(page_content, page_part, locale)
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

        # Save to Content
        content.send("raw_#{locale}=", rendered_html)
        content.save!
      rescue StandardError => e
        Rails.logger.error "[PagePartContent] Failed to regenerate: #{e.message}"
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
