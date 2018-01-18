module Pwb
  module ComponentHelper
    def page_part(page_content)
      unless page_content.is_rails_part
        content = page_content.content.present? ? page_content.content.raw : ""
        render partial: "pwb/components/generic_page_part", locals: { content: content }
      end
    end

    def page_component(component_name, page)
      components = []
      page.ordered_visible_page_contents.each do |page_content|
        # check for visible page contents
        if page_content.is_rails_part && (page_content.page_part_key == component_name)
          components.push page_content.page_part_key
        end
      end
      if components.include? component_name
       render partial: "pwb/components/#{component_name}", locals: {}
      end
    end
  end
end
