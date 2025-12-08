# frozen_string_literal: true

module Pwb
  module LiquidTags
    # Renders a property card for a specific property.
    #
    # Usage:
    #   {% property_card 123 %}
    #   {% property_card property_id %}
    #   {% property_card 123, style: "compact" %}
    #
    class PropertyCardTag < Liquid::Tag
      SYNTAX = /([\w-]+)(?:\s*,\s*(.*))?/

      def initialize(tag_name, markup, tokens)
        super
        if markup =~ SYNTAX
          @property_id = Regexp.last_match(1)
          @options = parse_options(Regexp.last_match(2))
        else
          raise Liquid::SyntaxError, "Syntax error in 'property_card' - Valid syntax: property_card [id], [options]"
        end
      end

      def render(context)
        property_id = context[@property_id] || @property_id
        view = context.registers[:view]
        website = context.registers[:website]

        return "" unless view && property_id

        property = find_property(property_id, website)
        return "" unless property

        style = @options[:style] || "default"
        partial = "pwb/components/property_cards/#{style}"

        begin
          view.render(partial: partial, locals: { property: property })
        rescue ActionView::MissingTemplate
          view.render(partial: "pwb/components/property_cards/default", locals: { property: property })
        end
      end

      private

      def find_property(id, website)
        scope = website ? Pwb::Prop.where(website_id: website.id) : Pwb::Prop
        scope.find_by(id: id) || scope.find_by(reference: id)
      end

      def parse_options(options_string)
        return {} unless options_string

        options_string.split(",").each_with_object({}) do |pair, hash|
          key, value = pair.strip.split(":").map(&:strip)
          hash[key.to_sym] = value.gsub(/["']/, "") if key && value
        end
      end
    end
  end
end

Liquid::Template.register_tag("property_card", Pwb::LiquidTags::PropertyCardTag)
