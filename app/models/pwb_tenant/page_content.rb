# frozen_string_literal: true

module PwbTenant
  # Join model for creating content for page
  # This join table provides flexibility to allow the same content
  # to be used by different pages with different settings for sorting and visibility
  class PageContent < ApplicationRecord
    belongs_to :page, optional: true, class_name: 'PwbTenant::Page'
    belongs_to :content, optional: true, class_name: 'PwbTenant::Content'

    validate :content_id_not_changed
    validates :page_part_key, presence: true

    before_validation :set_website_id_from_page, if: -> { website_id.blank? && page.present? }

    scope :ordered_visible, -> { where(visible_on_page: true).order('sort_order asc') }

    def as_json(options = nil)
      super({
        only: %w[sort_order visible_on_page],
        methods: %w[content content_page_part_key]
      }.merge(options || {}))
    end

    def content_page_part_key
      content.present? ? content.page_part_key : ''
    end

    private

    def content_id_not_changed
      if content_id_changed? && persisted?
        errors.add(:content_id, 'Change of content_id not allowed!') if content_id_was.present?
      end
    end

    def set_website_id_from_page
      self.website_id = page.website_id if page&.website_id.present?
    end
  end
end
