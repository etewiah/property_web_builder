module Pwb
  class PageContent < ApplicationRecord
    belongs_to :page
    belongs_to :content
    # https://stackoverflow.com/questions/5856838/scope-with-join-on-has-many-through-association

    scope :ordered_visible, -> () { where(visible_on_page: true).order('sort_order asc')  }

    def as_json(options = nil)
      super({only: [
               "sort_order", "visible_on_page"
             ],
             methods: ["content","content_fragment_key"]
             }.merge(options || {}))
    end

    def content_fragment_key
      content.fragment_key
    end

  end
end
