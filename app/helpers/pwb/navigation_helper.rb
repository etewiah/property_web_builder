module Pwb
  module NavigationHelper
    def render_omniauth_sign_in(provider)
      # will only render sign_in link for a provider for which config is present
      app_id_present = Rails.application.secrets["#{provider}_app_id"].present?
      app_secret_present = Rails.application.secrets["#{provider}_app_secret"].present?
      unless app_id_present && app_secret_present
        return
      end
      link_title = t(".sign_in_with_provider", provider: provider.to_s.titleize)
      link_path = send("localized_omniauth_path", provider)
      # link_path has to adapted to localised scope
      # https://github.com/plataformatec/devise/wiki/How-To:-OmniAuth-inside-localized-scope
      link_to link_title, link_path
      # localized_omniauth_path(provider)
    end

    def render_top_navigation_links
      html = ""
      @tn_links ||= Pwb::Link.ordered_visible_top_nav
      @tn_links.each do |page|
        unless page.slug == "top_nav_admin"
          html += (top_nav_link_for page) || ""
        end
      end
      html.html_safe
    end

    def render_footer_links
      html = ""
      @ftr_links ||= Pwb::Link.ordered_visible_footer
      @ftr_links.each do |page|
        html += (footer_link_for page) || ""
      end
      html.html_safe
    end

    def footer_link_for(page)
      html = ""
      begin
        if page[:link_path].present?
          # link_path should be valid - below checks that
          target_path = send(page[:link_path], [page[:link_path_params]], { locale: locale })
          # below works in most routes but had to change to above to support devise routes
          # target_path = send(page[:link_path], {locale: locale})
          # else
          #   target_path = self.send("show_page_path", page[:slug], {locale: locale})
        elsif page[:link_url].present?
          target_path = page[:link_url]
        end
      rescue NoMethodError
        # target_path = '/'
        # rescue Exception => e
      end
      if target_path
        html = <<-HTML
        #{link_to page.link_title, target_path}.
        HTML
      end
      html
    end

    def top_nav_link_for(page)
      html = ""
      begin
        if page[:link_path].present?
          # link_path should be valid - below checks that
          target_path = send(page[:link_path], [page[:link_path_params]], { locale: locale })
          # below works in most routes but had to change to above to support devise routes
          # target_path = send(page[:link_path], {locale: locale})
          # else
          #   target_path = self.send("show_page_path", page[:slug], {locale: locale})
        elsif page[:link_url].present?
          target_path = page[:link_url]
        end
      rescue NoMethodError
        # target_path = '/'
        # rescue Exception => e
      end
      if target_path
        style_class = "selected active" if current_page?(target_path)
        if current_page?("/") && (page[:link_path] == "home_path")
          # so correct tab is higlighted when at root path
          style_class = "selected active"
        end
        html = <<-HTML
        <li class="#{style_class}">
        #{link_to page.link_title, target_path, target: page[:href_target]}
        </li>
        HTML
      end
      html
    end
  end
end
