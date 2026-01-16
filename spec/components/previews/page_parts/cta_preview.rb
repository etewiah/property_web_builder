# frozen_string_literal: true

require_relative "../support/page_part_preview_helper"

# Previews for CTA (Call to Action) page parts
# Sections designed to encourage user action
#
# @label CTAs
class PageParts::CtaPreview < Lookbook::Preview
  include PagePartPreviewHelper

  # CTA Banner
  # Full-width call-to-action banner
  #
  # @label CTA Banner
  # @param theme select { choices: [default, brisbane, bologna, brussels] }
  def cta_banner(theme: "default")
    page_part = build_page_part("cta/cta_banner")
    
    render_liquid_template("cta/cta_banner", page_part, theme)
  end

  # CTA with Image
  # Split CTA with image on one side
  #
  # @label CTA Split Image
  # @param theme select { choices: [default, brisbane, bologna, brussels] }
  def cta_split_image(theme: "default")
    page_part = build_page_part("cta/cta_split_image")
    
    render_liquid_template("cta/cta_split_image", page_part, theme)
  end

  private

  def render_liquid_template(key, page_part, theme)
    # Use get_template which prefers YAML seed templates over view files
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
