# frozen_string_literal: true

module Pwb
  module LiquidTags
    # Renders a grid of featured properties.
    #
    # Usage:
    #   {% featured_properties %}
    #   {% featured_properties limit: 6 %}
    #   {% featured_properties limit: 4, type: "sale" %}
    #   {% featured_properties limit: 3, style: "compact", columns: 3 %}
    #
    class FeaturedPropertiesTag < Liquid::Tag
      VALID_TYPES = %w[sale rent all].freeze
      VALID_STYLES = %w[default compact card grid].freeze

      def initialize(tag_name, markup, tokens)
        super
        @options = parse_options(markup)
      end

      def render(context)
        view = context.registers[:view]
        website = context.registers[:website]

        return "" unless view

        properties = fetch_properties(website)
        return "" if properties.empty?

        style = @options[:style] || "default"
        columns = @options[:columns] || 3

        partial = "pwb/components/property_grids/#{style}"

        begin
          view.render(
            partial: partial,
            locals: {
              properties: properties,
              columns: columns.to_i,
              show_price: @options[:show_price] != "false",
              show_location: @options[:show_location] != "false"
            }
          )
        rescue ActionView::MissingTemplate
          view.render(
            partial: "pwb/components/property_grids/default",
            locals: { properties: properties, columns: columns.to_i }
          )
        end
      end

      private

      def fetch_properties(website)
        limit = (@options[:limit] || 6).to_i
        type = @options[:type] || "all"

        scope = website ? Pwb::Prop.where(website_id: website.id) : Pwb::Prop
        scope = scope.where(visible: true)

        case type
        when "sale"
          scope = scope.where(for_sale: true)
        when "rent"
          scope = scope.where(for_rent_long_term: true).or(scope.where(for_rent_short_term: true))
        end

        if @options[:highlighted] == "true"
          scope = scope.where(highlighted: true)
        end

        scope.order(created_at: :desc).limit(limit)
      end

      def parse_options(markup)
        options = {}
        markup.scan(/(\w+):\s*["']?([^"',]+)["']?/) do |key, value|
          options[key.to_sym] = value.strip
        end
        options
      end
    end
  end
end

Liquid::Template.register_tag("featured_properties", Pwb::LiquidTags::FeaturedPropertiesTag)
