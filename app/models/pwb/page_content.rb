# frozen_string_literal: true

module Pwb
  # PageContent is a join model connecting pages and content blocks.
  # Allows the same content to be used by different pages with different
  # settings for sorting and visibility.
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::PageContent for
  # tenant-scoped queries in web requests. This version is useful for
  # console work and cross-tenant operations.
# == Schema Information
#
# Table name: pwb_page_contents
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  is_rails_part          :boolean          default(FALSE)
#  label                  :string
#  page_part_key          :string
#  slot_name              :string
#  sort_order             :integer
#  visible_on_page        :boolean          default(TRUE)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  content_id             :bigint
#  page_id                :bigint
#  parent_page_content_id :bigint
#  website_id             :bigint
#
# Indexes
#
#  index_pwb_page_contents_on_content_id              (content_id)
#  index_pwb_page_contents_on_page_id                 (page_id)
#  index_pwb_page_contents_on_parent_and_slot         (parent_page_content_id,slot_name)
#  index_pwb_page_contents_on_parent_page_content_id  (parent_page_content_id)
#  index_pwb_page_contents_on_parent_slot_order       (parent_page_content_id,slot_name,sort_order)
#  index_pwb_page_contents_on_website_id              (website_id)
#
# Foreign Keys
#
#  fk_rails_...  (parent_page_content_id => pwb_page_contents.id)
#
  class PageContent < ApplicationRecord
    self.table_name = 'pwb_page_contents'

    # Core associations
    belongs_to :website, class_name: 'Pwb::Website', optional: true, touch: true
    belongs_to :page, optional: true, class_name: 'Pwb::Page'
    belongs_to :content, optional: true, class_name: 'Pwb::Content'

    # Container relationships for composable layouts
    belongs_to :parent_page_content,
               class_name: 'Pwb::PageContent',
               optional: true

    has_many :child_page_contents,
             class_name: 'Pwb::PageContent',
             foreign_key: :parent_page_content_id,
             dependent: :nullify

    # Validations
    validate :content_id_not_changed
    validates :page_part_key, presence: true
    validates :slot_name, presence: true, if: :has_parent?
    validate :parent_must_be_container
    validate :no_nested_containers
    validate :slot_exists_in_container

    before_validation :set_website_id_from_page, if: -> { website_id.blank? && page.present? }

    # Scopes
    scope :ordered_visible, -> { where(visible_on_page: true).order('sort_order asc') }
    scope :root_level, -> { where(parent_page_content_id: nil) }
    scope :in_slot, ->(slot) { where(slot_name: slot) }
    scope :ordered_in_slot, ->(slot) { in_slot(slot).order(:sort_order) }
    scope :ordered, -> { order(:sort_order) }

    # Container helper methods

    # Check if this page content is a container (can have children)
    def container?
      definition = Pwb::PagePartLibrary.definition(page_part_key)
      definition&.dig(:is_container) == true
    end

    # Check if this page content has a parent (is a child)
    def has_parent?
      parent_page_content_id.present?
    end

    # Check if this is a root-level page content (not a child)
    def root?
      !has_parent?
    end

    # Get children assigned to a specific slot, ordered by sort_order
    def children_in_slot(slot_name)
      child_page_contents.in_slot(slot_name).ordered
    end

    # Get all available slot names for this container
    def available_slots
      return [] unless container?
      definition = Pwb::PagePartLibrary.definition(page_part_key)
      definition&.dig(:slots)&.keys&.map(&:to_s) || []
    end

    # Get slot definition for a specific slot
    def slot_definition(slot_name)
      return nil unless container?
      definition = Pwb::PagePartLibrary.definition(page_part_key)
      definition&.dig(:slots, slot_name.to_sym)
    end

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

    # Validate that parent is a container page part
    def parent_must_be_container
      return unless has_parent?
      return if parent_page_content.nil? # Let belongs_to handle missing parent

      unless parent_page_content.container?
        errors.add(:parent_page_content, 'must be a container page part')
      end
    end

    # Validate that containers cannot be nested inside other containers
    def no_nested_containers
      if container? && has_parent?
        errors.add(:base, 'Containers cannot be nested inside other containers')
      end
    end

    # Validate that the slot_name is valid for the parent container
    def slot_exists_in_container
      return unless has_parent? && slot_name.present?
      return if parent_page_content.nil?

      available = parent_page_content.available_slots
      return if available.empty? # Skip validation if parent has no slots defined

      unless available.include?(slot_name.to_s)
        errors.add(:slot_name, "is not valid for this container. Available slots: #{available.join(', ')}")
      end
    end
  end
end
