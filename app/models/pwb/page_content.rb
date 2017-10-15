module Pwb
  class PageContent < ApplicationRecord
    belongs_to :page
    belongs_to :content
    # https://stackoverflow.com/questions/5856838/scope-with-join-on-has-many-through-association

    scope :ordered_visible, -> () { where(visible_on_page: true).order('sort_order asc')  }

    # if the page_content represents a rails_page_part, will return the page_part_key
    # else will return the raw html
    def get_html_or_page_part_key
      if self.is_rails_part
        # page_part_key
        return label
      else
        return content.present? ? content.raw : nil
      end
    end

    def as_json(options = nil)
      super({only: [
               "sort_order", "visible_on_page"
             ],
             methods: ["content","content_page_part_key"]
             }.merge(options || {}))
    end

    def content_page_part_key
      content.present? ? content.page_part_key : ""
    end

  end
end
