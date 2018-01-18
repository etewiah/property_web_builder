module Pwb
  module CssHelper
    def element_classes(*identifiers)
      classes = ""
      identifiers.each do |identifier|
        classes += @current_website.get_element_class(identifier) + " "
      end
      classes
    end

    def custom_styles(theme_name)
      @bg_style_vars = ["primary-color-light", "primary-color-dark",
                        "primary-color",
                        "accent-color", "divider-color",
                        "primary-background-dark"]
      @text_color_style_vars = ["primary-color-text",
                                "primary-text-color", "secondary-text-color"]
      render partial: "pwb/custom_css/#{theme_name}", locals: {}, formats: :css
    end
  end
end
