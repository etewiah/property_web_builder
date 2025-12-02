module Pwb
  module ApplicationHelper
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
      # binding.pry
      if agency.social_media.present? && agency.social_media[field_name].present?
        social_media = agency.social_media
      end
      if social_media
        html = <<-HTML
        <a href="#{agency.social_media[field_name]}" title="#{field_label}" target="_blank" class="">
        <i class="fa #{field_icon}"></i>
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
