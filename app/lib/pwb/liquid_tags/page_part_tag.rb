# frozen_string_literal: true

module Pwb
  module LiquidTags
    # Renders another page part inline.
    # Useful for composing page parts together.
    #
    # Usage:
    #   {% page_part "heroes/hero_centered" %}
    #   {% page_part "cta/cta_banner", style: "primary" %}
    #
    class PagePartTag < Liquid::Tag
      def initialize(tag_name, markup, tokens)
        super
        @markup = markup.strip
        parse_markup
      end

      def render(context)
        view = context.registers[:view]
        website = context.registers[:website]
        locale = context.registers[:locale] || I18n.locale

        return "" unless view && website

        page_part = find_page_part(website)
        return render_from_template(context) unless page_part

        # Render the page part content
        template_content = page_part.template_content
        return "" if template_content.blank?

        # Parse and render the Liquid template
        liquid_template = Liquid::Template.parse(template_content)
        block_contents = page_part.block_contents&.dig(locale.to_s, "blocks") || {}

        liquid_template.render(
          "page_part" => block_contents,
          registers: context.registers
        )
      end

      private

      def parse_markup
        if @markup =~ /["']([^"']+)["'](?:\s*,\s*(.*))?/
          @page_part_key = Regexp.last_match(1)
          @options = parse_options(Regexp.last_match(2))
        else
          @page_part_key = @markup.split(",").first&.strip
          @options = {}
        end
      end

      def find_page_part(website)
        Pwb::PagePart.find_by(
          website_id: website.id,
          page_part_key: @page_part_key
        )
      end

      def render_from_template(context)
        # Try to render directly from template file
        template_path = Pwb::PagePartLibrary.template_path(@page_part_key)
        return "" unless template_path

        template_content = File.read(template_path)
        liquid_template = Liquid::Template.parse(template_content)

        # Render with empty data (for preview/placeholder)
        liquid_template.render(
          "page_part" => {},
          registers: context.registers
        )
      end

      def parse_options(options_string)
        return {} unless options_string

        options_string.scan(/(\w+):\s*["']?([^"',]+)["']?/).to_h do |key, value|
          [key.to_sym, value.strip]
        end
      end
    end
  end
end

# Tag registration moved to config/initializers/liquid.rb
# to use Environment#register_tag instead of deprecated Template.register_tag
