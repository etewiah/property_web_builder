# frozen_string_literal: true

require_relative "../support/page_part_preview_helper"

# Previews for Stats page parts
# Number counters and statistics displays
#
# @label Stats
class PageParts::StatsPreview < Lookbook::Preview
  include PagePartPreviewHelper

  # Stats Counter
  # Animated number counters for statistics
  #
  # @label Stats Counter
  # @param theme select { choices: [default, brisbane, bologna, brussels] }
  def stats_counter(theme: "default")
    page_part = build_page_part("stats/stats_counter")
    
    render_liquid_template("stats/stats_counter", page_part, theme)
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
