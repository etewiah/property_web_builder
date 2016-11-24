module Pwb
  module ApplicationHelper
    def section_tab(section_info)
      begin
        target_path = send(section_info[:link_path], {locale: locale})

      rescue NoMethodError
        target_path = '/'
        # rescue Exception => e
      end
      # binding.pry
      style_class = 'selected' if current_page?( target_path )
      # section_info['link_path'](locale: locale))
      html = <<-HTML
      <li class="#{style_class}">
      #{link_to I18n.t('navbar.'+section_info[:link_key]), target_path}
      </li>
      HTML

      html.html_safe
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

  end
end
