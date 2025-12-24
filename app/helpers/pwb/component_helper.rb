module Pwb
  module ComponentHelper
    def page_part(page_content)
      unless page_content.is_rails_part
        content = page_content.content.present? ? page_content.content.raw : ""
        page_part_key = page_content.page_part_key
        edit_mode = params[:edit_mode] == 'true'
        render partial: "pwb/components/generic_page_part", locals: { 
          content: content, 
          page_part_key: page_part_key,
          edit_mode: edit_mode
        }
      end
    end

    def page_component(component_name, page)
      # Use a lighter query without eager loading :content since we only need
      # is_rails_part and page_part_key fields (avoids Bullet N+1 warning)
      has_component = page.page_contents
        .where(is_visible: true, is_rails_part: true, page_part_key: component_name)
        .exists?

      if has_component
        render partial: "pwb/components/#{component_name}", locals: {}
      end
    end
  end
end
