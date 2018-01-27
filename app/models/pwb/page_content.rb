module Pwb
  class PageContent < ApplicationRecord
    # Join model for creating content for page
    # Would have been easier in the short run to have pages simply belong_to
    # content directly.
    # This join table provides flexibility in the long run to allow the
    # same content to be used by different pages
    # with different settings for sorting and visibility
    # Might have been better to call this model PagePlaceholder
    belongs_to :page
    belongs_to :content
    belongs_to :website
    # https://stackoverflow.com/questions/5856838/scope-with-join-on-has-many-through-association


    validate :content_id_not_changed




    # page_part_key
    validates_presence_of :page_part_key

    # this join model is used for sorting and visibility
    # (instead of a value on the content itself) as it
    # will allow use of same content by different pages
    # with different settings for sorting and visibility

    scope :ordered_visible, -> () { where(visible_on_page: true).order('sort_order asc') }

    # if the page_content represents a rails_page_part, will return the page_part_key
    # else will return the raw html
    # def get_html_or_page_part_key
    #   if self.is_rails_part
    #     # page_part_key
    #     return page_part_key
    #   else
    #     return content.present? ? content.raw : nil
    #   end
    # end

    def as_json(options = nil)
      super({only: [
               "sort_order", "visible_on_page"
             ],
             methods: ["content", "content_page_part_key"]
             }.merge(options || {}))
    end

    def content_page_part_key
      content.present? ? content.page_part_key : ""
    end

    private

    def content_id_not_changed
      if content_id_changed? && persisted?
        if content_id_was.blank?
          nil
        else
          errors.add(:content_id, "Change of content_id not allowed!")
        end
      end
    end
  end
end
