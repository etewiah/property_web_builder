module Pwb
  module CssHelper
    # Minimal critical CSS for above-the-fold content
    # This should be inlined in the <head> for fastest FCP
    CRITICAL_CSS = <<~CSS.freeze
      *,::after,::before{box-sizing:border-box;border:0 solid}
      html{line-height:1.5;-webkit-text-size-adjust:100%;font-family:ui-sans-serif,system-ui,sans-serif}
      body{margin:0;line-height:inherit}
      h1,h2,h3,h4,h5,h6{font-size:inherit;font-weight:inherit}
      a{color:inherit;text-decoration:inherit}
      img,video{max-width:100%;height:auto;display:block}
      .container{width:100%;margin-left:auto;margin-right:auto;padding-left:1rem;padding-right:1rem}
      @media(min-width:640px){.container{max-width:640px}}
      @media(min-width:768px){.container{max-width:768px;padding-left:1.5rem;padding-right:1.5rem}}
      @media(min-width:1024px){.container{max-width:1024px}}
      @media(min-width:1280px){.container{max-width:1280px}}
      .flex{display:flex}.flex-col{flex-direction:column}.items-center{align-items:center}
      .justify-between{justify-content:space-between}.min-h-screen{min-height:100vh}
      .flex-grow{flex-grow:1}.hidden{display:none}.block{display:block}
      .text-white{color:#fff}.bg-white{background-color:#fff}
      .sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);border:0}
    CSS

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

    # Returns minimal critical CSS for immediate rendering
    # Use this inline in <head> before any external stylesheets
    def critical_css
      CRITICAL_CSS
    end

    # Check if critical CSS file exists for a theme
    def critical_css_file_exists?(theme_name)
      path = Rails.root.join("app", "assets", "builds", "critical-#{theme_name}.css")
      File.exist?(path)
    end

    # Read critical CSS file for a theme (if extracted via npm run critical:extract)
    def critical_css_for_theme(theme_name)
      path = Rails.root.join("app", "assets", "builds", "critical-#{theme_name}.css")
      if File.exist?(path)
        File.read(path)
      else
        CRITICAL_CSS
      end
    end
  end
end
