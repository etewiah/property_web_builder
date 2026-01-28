module Pwb
  module ComponentHelper
    include UrlLocalizationHelper

    def page_part(page_content)
      return if page_content.is_rails_part

      page_part_key = page_content.page_part_key
      edit_mode = params[:edit_mode] == 'true'

      # Check if this is a container page part
      if page_content.container?
        render_container_page_part(page_content, edit_mode)
      else
        content = page_content.content.present? ? page_content.content.raw : ""
        # Localize URLs in HTML content based on current locale
        content = localize_html_urls(content)
        render partial: "pwb/components/generic_page_part", locals: {
          content: content,
          page_part_key: page_part_key,
          edit_mode: edit_mode
        }
      end
    end

    # Renders a container page part dynamically at display time
    # This is necessary because containers need access to page_content
    # to render their children via the render_slot Liquid tag
    def render_container_page_part(page_content, edit_mode = false)
      website = @current_website || Pwb::Current.website
      locale = I18n.locale.to_s
      page_part_key = page_content.page_part_key

      # Find the PagePart for template and block_contents
      page_part_record = Pwb::PagePart.find_by(
        website_id: website&.id,
        page_part_key: page_part_key
      )

      # Get the template
      template_content = page_part_record&.template_content
      if template_content.blank?
        template_path = Pwb::PagePartLibrary.template_path(page_part_key)
        template_content = File.read(template_path) if template_path && File.exist?(template_path)
      end
      return "" if template_content.blank?

      # Get block_contents
      block_contents = page_part_record&.block_contents&.dig(locale, "blocks") || {}

      # Parse the Liquid template
      liquid_template = Liquid::Template.parse(template_content)

      # Build context with registers set properly for Liquid 5.x
      context = Liquid::Context.new
      context["page_part"] = block_contents
      context.registers[:view] = self
      context.registers[:website] = website
      context.registers[:locale] = locale
      context.registers[:page_content] = page_content

      rendered_html = liquid_template.render(context)

      # Wrap in container div with optional edit-mode attribute
      wrapper_attrs = {
        class: "pwb-container-wrapper",
        "data-page-part-key": page_part_key
      }
      wrapper_attrs["data-pwb-page-part"] = page_part_key if edit_mode
      content_tag(:div, rendered_html.html_safe, wrapper_attrs)
    rescue StandardError => e
      Rails.logger.error("Container rendering error for #{page_part_key}: #{e.message}")
      ""
    end

    def page_component(component_name, page)
      # Use a lighter query without eager loading :content since we only need
      # is_rails_part and page_part_key fields (avoids Bullet N+1 warning)
      has_component = page.page_contents
        .where(visible_on_page: true, is_rails_part: true, page_part_key: component_name)
        .exists?

      if has_component
        render partial: "pwb/components/#{component_name}", locals: {}
      end
    end
  end
end
