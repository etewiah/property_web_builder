# frozen_string_literal: true

module Pwb
  module LiquidTags
    # Renders child page contents assigned to a specific slot within a container.
    # Only meaningful inside container page part templates.
    #
    # Usage:
    #   {% render_slot "left" %}
    #   {% render_slot "main" %}
    #   {% render_slot "sidebar" %}
    #
    # The tag looks for child PageContent records assigned to the named slot
    # and renders each one using its page_part_key template.
    #
    class RenderSlotTag < Liquid::Tag
      def initialize(tag_name, markup, tokens)
        super
        @markup = markup.strip
        parse_markup
      end

      def render(context)
        website = context.registers[:website]
        locale = context.registers[:locale] || I18n.locale
        page_content = context.registers[:page_content]

        # Only require page_content - website and view may be optional in some contexts
        return "" unless page_content

        # Verify this is a container
        return slot_error("Not a container") unless page_content.container?

        # Get children for this slot
        children = page_content.children_in_slot(@slot_name)
        return "" if children.empty?

        # Render each child page content
        rendered_parts = children.map do |child_page_content|
          render_child(child_page_content, context, locale)
        end

        rendered_parts.join("\n")
      end

      private

      def parse_markup
        if @markup =~ /["']([^"']+)["']/
          @slot_name = Regexp.last_match(1)
        else
          @slot_name = @markup.split(/\s+/).first&.strip
        end
      end

      def render_child(child_page_content, context, locale)
        page_part_key = child_page_content.page_part_key
        return "" if page_part_key.blank?

        website = context.registers[:website]

        # Find the PagePart to get block_contents and template
        page_part = Pwb::PagePart.find_by(
          website_id: website&.id,
          page_part_key: page_part_key
        )

        # Get block_contents from PagePart (the JSON data)
        block_contents = page_part&.block_contents&.dig(locale.to_s, "blocks") || {}

        # Get the template - prefer PagePart's template_content, fallback to file
        template_content = page_part&.template_content
        if template_content.blank?
          template_path = Pwb::PagePartLibrary.template_path(page_part_key)
          return "" unless template_path && File.exist?(template_path)
          template_content = File.read(template_path)
        end

        liquid_template = Liquid::Template.parse(template_content)

        # Build child context - use Liquid::Context with registers set properly
        child_context = Liquid::Context.new
        child_context["page_part"] = block_contents
        child_context.registers[:page_content] = child_page_content
        child_context.registers[:website] = website
        child_context.registers[:locale] = locale

        liquid_template.render(child_context)
      rescue StandardError => e
        Rails.logger.error("RenderSlotTag error for #{page_part_key}: #{e.message}")
        ""
      end

      def slot_error(message)
        return "" unless Rails.env.development?

        "<!-- render_slot error: #{message} -->"
      end
    end
  end
end

# Tag registration is in config/initializers/liquid.rb
