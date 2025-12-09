# frozen_string_literal: true

module Pwb
  module LiquidTags
    # Renders a contact form.
    #
    # Usage:
    #   {% contact_form %}
    #   {% contact_form style: "compact" %}
    #   {% contact_form style: "inline", property_id: 123 %}
    #
    class ContactFormTag < Liquid::Tag
      VALID_STYLES = %w[default compact inline sidebar].freeze

      def initialize(tag_name, markup, tokens)
        super
        @options = parse_options(markup)
      end

      def render(context)
        view = context.registers[:view]
        website = context.registers[:website]

        return "" unless view

        style = @options[:style] || "default"
        property_id = context[@options[:property_id]] || @options[:property_id]

        partial = "pwb/components/contact_forms/#{style}"

        locals = {
          website: website,
          property_id: property_id,
          show_phone: @options[:show_phone] != "false",
          show_message: @options[:show_message] != "false",
          button_text: @options[:button_text] || "Send Message",
          success_message: @options[:success_message] || "Thank you for your message!"
        }

        begin
          view.render(partial: partial, locals: locals)
        rescue ActionView::MissingTemplate
          view.render(partial: "pwb/components/contact_forms/default", locals: locals)
        end
      end

      private

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

# Tag registration moved to config/initializers/liquid.rb
# to use Environment#register_tag instead of deprecated Template.register_tag
