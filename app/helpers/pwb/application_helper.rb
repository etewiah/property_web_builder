module Pwb
  module ApplicationHelper

    def area_unit(property)
      area_unit = "m<sup>2</sup>"
      if property.area_unit && (property.area_unit == "feet")
        area_unit = "sqft"
      end
      area_unit.html_safe
    end

    def localized_link_to(name = nil, options = nil, html_options = nil)
      if params["controller"] && params["controller"].include?("devise/")
        link = "<a class='#{options["locale"]}' href='/#{options["locale"]}'></a>"
        return link.html_safe
      else
        return link_to name, options, html_options
      end
    end

    def t_or_unknown key
      if key.is_a?(String) && key.empty?
        return t "unknown"
      else
        return t key
      end
    end

    def section_tab(section_info)
      begin
        # link_path should be valid - below checks that
        target_path = self.pwb.send(section_info[:link_path], {locale: locale})
        # below works in most routes but had to change to above to support devise routes
        # target_path = send(section_info[:link_path], {locale: locale})
      rescue NoMethodError
        # target_path = '/'
        # rescue Exception => e
      end

      # only show section_tab where link_path is valid
      if target_path
        style_class = 'selected active' if current_page?( target_path )
        html = <<-HTML
        <li class="#{style_class}">
        #{link_to I18n.t('navbar.'+section_info[:link_key]), target_path}
        </li>
        HTML

        html.html_safe
      end

    end


    # http://railscasts.com/episodes/75-complex-forms-part-3
    def simple_inmo_input(f, field_key, placeholder_key, input_type, required)
      placeholder = placeholder_key.present? ? I18n.t("placeHolders." + placeholder_key) : ""
      label_class = required ? "obligatorio" : ""
      html = <<-HTML
      <label class=#{ label_class }>
        #{ I18n.t(field_key) }
        </label>
      #{ f.text_field field_key, :class => 'form-control texto',
      :type => input_type,
        :required => required, :"aria-required" => required, :placeholder => placeholder }
      <div class="validacion"></div>
      HTML

      html.html_safe
    end

    def simple_inmo_textarea(f, field_key, placeholder_key, input_type, required, height=150)
      placeholder = placeholder_key.present? ? I18n.t("placeHolders." + placeholder_key) : ""
      label_class = required ? "obligatorio" : ""
      style = "height:#{height}px"
      html = <<-HTML
      <label class=#{ label_class }>
        #{ I18n.t(field_key) }
        </label>
      #{ f.text_area field_key, :class => 'form-control',
      :style => style, :required => required,
        :"aria-required" => required, :placeholder => placeholder }
      <div class="validacion"></div>
      HTML

      html.html_safe
    end


    def social_media_link(agency, field_name, field_label, field_icon)
      # binding.pry
      if agency && agency.social_media[field_name].present?
        html = <<-HTML
        <a href="#{ agency.social_media[field_name] }" title="#{ field_label }" target="_blank" class="">
        <i class="fa #{ field_icon }"></i>
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
        <h5><i class="fa #{ field_icon }"></i>#{I18n.t field_label_key }</h5>
        <p>#{ agency[field_name] }</p>
        HTML

        html.html_safe
      else
        ""
      end
    end
  end
end
