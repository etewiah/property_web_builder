module Pwb
  module NavigationHelper

    def top_navigation
      html = ""
      @pages ||= Pwb::Page.all
      # TODO - cache here
      @pages.order("sort_order_top_nav").each do |page|
        if page.show_in_top_nav
          html += (top_nav_link_for_page page) || ""
        end
      end
      html.html_safe
    end

    def footer_links
      html = ""
      @pages ||= Pwb::Page.all
      # TODO - cache here
      @pages.order("sort_order_footer").each do |page|
        if page.show_in_footer
          html += (footer_link page) || ""
        end
      end
      html.html_safe
    end

    def footer_link(page)
      html = ""
      begin
        if page[:link_path].present?
          # link_path should be valid - below checks that
          target_path = self.pwb.send(page[:link_path], {locale: locale})
          # below works in most routes but had to change to above to support devise routes
          # target_path = send(page[:link_path], {locale: locale})
        else
          target_path = self.pwb.send("show_page_path", page[:slug], {locale: locale})
        end
      rescue NoMethodError
        # target_path = '/'
        # rescue Exception => e
      end
      if target_path
        html = <<-HTML
        #{ link_to page.link_title, target_path}.
        HTML
      end
      html
    end

    def top_nav_link_for_page(page)
      html = ""
      begin
        if page[:link_path].present?
          # link_path should be valid - below checks that
          target_path = self.pwb.send(page[:link_path], {locale: locale})
          # below works in most routes but had to change to above to support devise routes
          # target_path = send(page[:link_path], {locale: locale})
        else
          target_path = self.pwb.send("show_page_path", page[:slug], {locale: locale})
        end
      rescue NoMethodError
        # target_path = '/'
        # rescue Exception => e
      end
      if target_path
        style_class = 'selected active' if current_page?( target_path )
        html = <<-HTML
        <li class="#{style_class}">
        #{link_to page.link_title, target_path}
        </li>
        HTML
      end
      html
    end

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


  end
end
