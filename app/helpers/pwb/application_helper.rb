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
  end
end
