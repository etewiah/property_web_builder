module Pwb
  module ApplicationHelper
    include CurrencyHelper

    # Display property price with optional currency conversion
    #
    # If the user has selected a different currency and exchange rates are available,
    # shows the original price with converted price in parentheses.
    # For rental properties, appends "/month" to indicate the rental period.
    #
    # @param property [ListedProperty] the property to get price from
    # @param operation_type [String] "for_sale" or "for_rent"
    # @param show_conversion [Boolean] whether to show converted price
    # @return [String] formatted price string (HTML safe)
    #
    # @example
    #   property_price(@property, "for_sale")
    #   # => "€250,000" (default currency)
    #   # => "€250,000 <span class='text-gray-500'>(~$270,000 USD)</span>" (with conversion)
    #   property_price(@property, "for_rent")
    #   # => "$2,200/month"
    #
    def property_price(property, operation_type, show_conversion: true)
      money = property.contextual_price(operation_type)
      formatted = display_price(money, show_conversion: show_conversion)

      # Add "/month" suffix for rental prices
      if formatted.present? && operation_type.to_s == "for_rent"
        # Insert /month before any conversion span or at the end
        if formatted.include?("<span")
          formatted.sub(" <span", "/#{t('properties.month', default: 'month')} <span").html_safe
        else
          "#{formatted}/#{t('properties.month', default: 'month')}".html_safe
        end
      else
        formatted
      end
    end

    # Format bathroom count, removing unnecessary decimals
    #
    # @param count [Float, Integer, nil] the bathroom count
    # @return [String] formatted count (e.g., "2" instead of "2.0", but "1.5" preserved)
    #
    # @example
    #   format_bathroom_count(2.0)  # => "2"
    #   format_bathroom_count(1.5)  # => "1.5"
    #   format_bathroom_count(nil)  # => ""
    #
    def format_bathroom_count(count)
      return "" if count.nil?

      # If it's a whole number, display as integer
      count == count.to_i ? count.to_i.to_s : count.to_s
    end

    # Format bedroom count, removing unnecessary decimals
    #
    # @param count [Float, Integer, nil] the bedroom count
    # @return [String] formatted count
    #
    def format_bedroom_count(count)
      return "" if count.nil?

      count == count.to_i ? count.to_i.to_s : count.to_s
    end

    # Locale-aware path helpers
    # These ensure URLs always include the current locale prefix for consistency
    #
    # @example
    #   localized_buy_path  # => "/en/buy" (when locale is :en)
    #   localized_rent_path # => "/es/rent" (when locale is :es)
    #
    def localized_buy_path
      buy_path(locale: I18n.locale)
    end

    def localized_rent_path
      rent_path(locale: I18n.locale)
    end

    def localized_contact_path
      contact_us_path(locale: I18n.locale)
    end

    def localized_home_path
      home_path(locale: I18n.locale)
    end

    # Consolidated company display name resolution
    # Provides consistent fallback logic across all themes
    # Priority: agency.display_name > agency.company_name > website.company_display_name (deprecated) > default
    #
    # NOTE: website.company_display_name is DEPRECATED and only used as a legacy fallback.
    # New installations should set display_name on the Agency model instead.
    # The agency display_name field can be edited in Admin > Agency Profile.
    def company_display_name(default_value = "Real Estate")
      @current_agency&.display_name.presence ||
        @current_agency&.company_name.presence ||
        @current_website&.company_display_name.presence ||
        default_value
    end

    # Legal company name for copyright/contracts
    # Priority: agency.company_name > agency.display_name > website.company_display_name (deprecated) > default
    #
    # NOTE: website.company_display_name is DEPRECATED - see company_display_name above.
    def company_legal_name(default_value = "Real Estate")
      @current_agency&.company_name.presence ||
        @current_agency&.display_name.presence ||
        @current_website&.company_display_name.presence ||
        default_value
    end

    def properties_carousel_footer
      # TODO: - diplay array of thumbnails below main
      # properties carousel is images count > ...
      # <a href="#" class="theater" rel="group" hidefocus="true">
      # <%= opt_image_tag((@property_details.ordered_photo 3), :quality => "auto", class: "", alt: "") %>
      # </a>
    end

    def page_title(title_val)
      content_for :page_title, title_val.to_s
    end

    # def meta_tags(tags_array = [])
    #   tags_string = ""
    #   tags_array.each do |tag|
    #     tags_string += "<meta property='#{tag[:property]}' content='#{tag[:content]}' />"
    #   end
    #   content_for :page_head, tags_string
    #   # <meta property="og:image" content="http://examples.opengraphprotocol.us/media/images/75.png">
    # end

    def area_unit(property)
      area_unit = "m<sup>2</sup>"
      if property.area_unit && (property.area_unit == "sqft")
        area_unit = "sqft"
      end
      area_unit.html_safe
    end

    def localized_link_to(locale_with_var = nil, options = nil, _html_options = nil)
      link_class = locale_with_var["variant"]
      href = "/#{options['locale']}"
      begin
        href = url_for(options)
      rescue ActionController::UrlGenerationError
      end
      link = "<a class='#{link_class}' href='#{href}'></a>"
      link.html_safe

      # if params["controller"] && params["controller"].include?("devise/")
      #   link = "<a class='#{link_class}' href='/#{options["locale"]}'></a>"
      #   return link.html_safe
      # else
      #   return link_to "", options, html_options
      # end
    end

    def t_or_unknown(key)
      if key.is_a?(String) && key.empty?
        t "unknown"
      else
        t key
      end
    end

    # below replaced with methods in navigation_helper file (spt 2017)
    # def top_nav_link(section_info)
    #   unless section_info.show_in_top_nav
    #     return
    #   end
    #   begin
    #     if section_info.is_page
    #       target_path = self.pwb.send("generic_page_path", section_info[:link_path], {locale: locale})
    #     else

    #       # link_path should be valid - below checks that
    #       target_path = self.pwb.send(section_info[:link_path], {locale: locale})
    #       # below works in most routes but had to change to above to support devise routes
    #       # target_path = send(section_info[:link_path], {locale: locale})
    #     end
    #   rescue NoMethodError
    #     # target_path = '/'
    #     # rescue Exception => e
    #   end
    #   # only show top_nav_link where link_path is valid
    #   if target_path
    #     style_class = 'selected active' if current_page?( target_path )
    #     html = <<-HTML
    #     <li class="#{style_class}">
    #     #{link_to I18n.t('navbar.'+section_info[:link_key]), target_path}
    #     </li>
    #     HTML

    #     html.html_safe
    #   end
    # end

    # def footer_link(section_info, class_name="")
    #   unless section_info.show_in_footer
    #     return
    #   end
    #   begin
    #     if section_info.is_page
    #       target_path = self.pwb.send("generic_page_path", section_info[:link_path], {locale: locale})
    #     else
    #       target_path = self.pwb.send(section_info[:link_path], {locale: locale})
    #     end
    #   rescue NoMethodError
    #   end

    #   if target_path
    #     html = <<-HTML
    #     #{ link_to I18n.t('navbar.'+section_info[:link_key]), target_path, class: class_name}.
    #     HTML
    #     html.html_safe
    #   end
    # end

    # http://railscasts.com/episodes/75-complex-forms-part-3
    def simple_inmo_input(f, field_key, placeholder_key, input_type, required)
      placeholder = placeholder_key.present? ? I18n.t("placeHolders." + placeholder_key) : ""
      label_class = required ? "obligatorio" : ""
      html = <<-HTML
      <label class=#{label_class}>
        #{I18n.t(field_key)}
        </label>
      #{f.text_field field_key, :class => 'form-control texto',
      :type => input_type,
        :required => required, :"aria-required" => required, :placeholder => placeholder}
      <div class="validacion"></div>
      HTML

      html.html_safe
    end

    def tailwind_inmo_input(f, field_key, placeholder_key, input_type, required)
      placeholder = placeholder_key.present? ? I18n.t("placeHolders." + placeholder_key) : ""
      label_class = "block text-sm font-medium text-gray-700 mb-1"
      input_class = "w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
      required_indicator = required ? '<span class="text-red-500">*</span>' : ""
      
      html = <<-HTML
      <div>
        <label class="#{label_class}">
          #{I18n.t(field_key)} #{required_indicator}
        </label>
        #{f.text_field field_key, :class => input_class,
        :type => input_type,
          :required => required, :"aria-required" => required, :placeholder => placeholder}
      </div>
      HTML

      html.html_safe
    end

    def tailwind_inmo_textarea(f, field_key, placeholder_key, _input_type, required, rows = 5)
      placeholder = placeholder_key.present? ? I18n.t("placeHolders." + placeholder_key) : ""
      label_class = "block text-sm font-medium text-gray-700 mb-1"
      input_class = "w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
      required_indicator = required ? '<span class="text-red-500">*</span>' : ""

      html = <<-HTML
      <div>
        <label class="#{label_class}">
          #{I18n.t(field_key)} #{required_indicator}
        </label>
        #{f.text_area field_key, :class => input_class,
        :rows => rows, :required => required,
          :"aria-required" => required, :placeholder => placeholder}
      </div>
      HTML

      html.html_safe
    end

    def simple_inmo_textarea(f, field_key, placeholder_key, _input_type, required, height = 150)
      placeholder = placeholder_key.present? ? I18n.t("placeHolders." + placeholder_key) : ""
      label_class = required ? "obligatorio" : ""
      style = "height:#{height}px"
      html = <<-HTML
      <label class=#{label_class}>
        #{I18n.t(field_key)}
        </label>
      #{f.text_area field_key, :class => 'form-control',
      :style => style, :required => required,
        :"aria-required" => required, :placeholder => placeholder}
      <div class="validacion"></div>
      HTML

      html.html_safe
    end

    def social_media_link(agency, field_name, field_label, field_icon)
      social_media = nil

      if agency.social_media.present? && agency.social_media[field_name].present?
        social_media = agency.social_media
      end
      if social_media
        aria_label = "Follow us on #{field_label}"
        html = <<-HTML
        <a href="#{agency.social_media[field_name]}" title="#{field_label}" target="_blank" rel="noopener noreferrer" aria-label="#{aria_label}">
        <i class="fa #{field_icon}" aria-hidden="true"></i>
        </a>
        HTML

        html.html_safe
      else
        ""
      end
    end

    def agency_info(agency, field_name, field_label_key, field_icon)
      if agency && agency[field_name].present?
        html = <<-HTML
        <h5><i class="fa #{field_icon}"></i>#{I18n.t field_label_key}</h5>
        <p>#{agency[field_name]}</p>
        HTML

        html.html_safe
      else
        ""
      end
    end
  end
end
