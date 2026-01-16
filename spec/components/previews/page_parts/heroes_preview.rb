# frozen_string_literal: true

require_relative "../support/page_part_preview_helper"

# Previews for Hero page parts
# These are the main banner sections typically used at the top of pages
#
# @label Heroes
class PageParts::HeroesPreview < Lookbook::Preview
  include PagePartPreviewHelper

  # Centered Hero
  # Full-width hero with centered content and optional CTA buttons
  #
  # @label Hero Centered
  # @param theme select { choices: [default, brisbane, bologna, brussels] }
  def hero_centered(theme: "default")
    page_part = build_page_part("heroes/hero_centered")
    
    render_liquid_template("heroes/hero_centered", page_part, theme)
  end

  # Split Hero
  # Two-column hero with content on one side and image on the other
  #
  # @label Hero Split
  # @param theme select { choices: [default, brisbane, bologna, brussels] }
  def hero_split(theme: "default")
    page_part = build_page_part("heroes/hero_split")
    
    render_liquid_template("heroes/hero_split", page_part, theme)
  end

  # Hero with Search
  # Hero section with integrated property search form
  #
  # @label Hero with Search
  # @param theme select { choices: [default, brisbane, bologna, brussels] }
  def hero_search(theme: "default")
    page_part = build_page_part("heroes/hero_search")
    
    render_liquid_template("heroes/hero_search", page_part, theme)
  end

  private

  def render_liquid_template(key, page_part, theme)
    template_path = Rails.root.join("app/views/pwb/page_parts/#{key}.liquid")
    
    if File.exist?(template_path)
      template_content = File.read(template_path)
      liquid_template = Liquid::Template.parse(template_content)
      
      html = liquid_template.render(
        "page_part" => page_part,
        "locale" => "en"
      )
      
      # Wrap with theme styles
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
