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

    # Render palette CSS based on the website's palette mode
    # In compiled mode: returns pre-generated static CSS
    # In dynamic mode: returns CSS with variable declarations
    #
    # @return [String] CSS string (safe to inline in <style> tag)
    def palette_css
      return "" unless @current_website

      @current_website.palette_css
    end

    # Check if website is in dynamic palette mode
    # @return [Boolean]
    def palette_dynamic?
      @current_website&.palette_dynamic?
    end

    # Check if website is in compiled palette mode
    # @return [Boolean]
    def palette_compiled?
      @current_website&.palette_compiled?
    end

    # Check if compiled palette is stale and needs recompilation
    # @return [Boolean]
    def palette_stale?
      @current_website&.palette_stale?
    end

    # ===================
    # Font Loading Helpers
    # ===================

    # Get the FontLoader instance (memoized)
    # @return [Pwb::FontLoader]
    def font_loader
      @font_loader ||= Pwb::FontLoader.new
    end

    # Generate complete font loading HTML for the current website
    # Includes preconnect, Google Fonts link, and CSS variables
    # Use this in the <head> section of layouts
    #
    # @return [String] HTML for font loading
    def font_loading_tags
      return "" unless @current_website

      font_loader.font_loading_html(@current_website)
    end

    # Generate Google Fonts preconnect tags
    # Use early in <head> for best performance
    #
    # @return [String] Preconnect link tags
    def font_preconnect_tags
      return "" unless @current_website
      return "" unless fonts_need_loading?

      font_loader.preconnect_tags
    end

    # Generate Google Fonts stylesheet link
    # @return [String] Link tag for Google Fonts or empty string
    def google_fonts_link_tag
      return "" unless @current_website

      url = font_loader.google_fonts_url_for_website(@current_website)
      return "" unless url

      %(<link href="#{url}" rel="stylesheet">).html_safe
    end

    # Generate Google Fonts preload link for better performance
    # @return [String] Preload link tag
    def google_fonts_preload_tag
      return "" unless @current_website

      url = font_loader.google_fonts_url_for_website(@current_website)
      return "" unless url

      <<~HTML.html_safe
        <link rel="preload" href="#{url}" as="style" onload="this.onload=null;this.rel='stylesheet'">
        <noscript><link href="#{url}" rel="stylesheet"></noscript>
      HTML
    end

    # Generate CSS variables for fonts
    # @return [String] CSS with --pwb-font-* variables
    def font_css_variables
      return "" unless @current_website

      font_loader.font_css_variables(@current_website)
    end

    # Check if the current website requires font loading
    # @return [Boolean]
    def fonts_need_loading?
      return false unless @current_website

      font_loader.fonts_to_load(@current_website).any?
    end

    # Get the current primary font name
    # @return [String]
    def primary_font_name
      return "Open Sans" unless @current_website

      font_loader.fonts_for_website(@current_website)[:primary]
    end

    # Get the current heading font name
    # @return [String]
    def heading_font_name
      return "Montserrat" unless @current_website

      font_loader.fonts_for_website(@current_website)[:heading]
    end
  end
end
