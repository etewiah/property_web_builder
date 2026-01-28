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
        view = context.registers[:view]
        website = context.registers[:website]
        locale = context.registers[:locale] || I18n.locale
        page_content = context.registers[:page_content]

        return "" unless view && website && page_content

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

        # Find the content data
        content = child_page_content.content
        block_contents = if content&.raw.present?
                           content.raw
                         else
                           {}
                         end

        # Get the template
        template_path = Pwb::PagePartLibrary.template_path(page_part_key)
        return "" unless template_path && File.exist?(template_path)

        template_content = File.read(template_path)
        liquid_template = Liquid::Template.parse(template_content)

        # Build child context with its own page_content
        child_registers = context.registers.merge(page_content: child_page_content)

        liquid_template.render(
          "page_part" => block_contents,
          registers: child_registers
        )
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
