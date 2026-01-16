# frozen_string_literal: true

require_relative "../support/page_part_preview_helper"

# Previews for FAQ page parts
# Frequently asked questions sections
#
# @label FAQs
class PageParts::FaqsPreview < Lookbook::Preview
  include PagePartPreviewHelper

  # FAQ Accordion
  # Expandable FAQ section
  #
  # @label FAQ Accordion
  # @param theme select { choices: [default, brisbane, bologna, brussels] }
  def faq_accordion(theme: "default")
    page_part = build_page_part("faqs/faq_accordion")
    
    render_liquid_template("faqs/faq_accordion", page_part, theme)
  end

  private

  def render_liquid_template(key, page_part, theme)
    template_content = get_template(key)

    if template_content.present?
      liquid_template = Liquid::Template.parse(template_content)

      html = liquid_template.render(
        "page_part" => page_part,
        "locale" => "en"
      )

      palette = PALETTES[theme.to_sym] || PALETTES[:default]
      wrapped_html = <<~HTML
        <div class="pwb-preview" style="
          --pwb-primary: #{palette[:primary_color]};
          --pwb-secondary: #{palette[:secondary_color]};
          --pwb-accent: #{palette[:accent_color]};
          --pwb-background: #{palette[:background_color]};
          --pwb-text: #{palette[:text_color]};
        ">
          #{html}
        </div>
      HTML

      render template: "lookbook/previews/liquid_wrapper", locals: { html: wrapped_html.html_safe }
    else
      error_html = "<div class='error'>Template not found: #{key}</div>"
      render template: "lookbook/previews/liquid_wrapper", locals: { html: error_html.html_safe }
    end
  end
end
