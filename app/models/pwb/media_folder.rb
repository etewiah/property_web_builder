# frozen_string_literal: true

module Pwb
  # MediaFolder represents a folder for organizing media files.
  #
  # Supports nested folders (parent/child relationship) and
  # automatic slug generation for URL-friendly paths.
# == Schema Information
#
# Table name: pwb_media_folders
# Database name: primary
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  slug       :string
#  sort_order :integer          default(0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  parent_id  :bigint
#  website_id :bigint           not null
#
# Indexes
#
#  index_pwb_media_folders_on_parent_id                 (parent_id)
#  index_pwb_media_folders_on_website_id                (website_id)
#  index_pwb_media_folders_on_website_id_and_parent_id  (website_id,parent_id)
#  index_pwb_media_folders_on_website_id_and_slug       (website_id,slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (parent_id => pwb_media_folders.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
  class MediaFolder < ApplicationRecord
    self.table_name = 'pwb_media_folders'

    # Associations
    belongs_to :website, class_name: 'Pwb::Website'
    belongs_to :parent, class_name: 'Pwb::MediaFolder', optional: true
    has_many :children, class_name: 'Pwb::MediaFolder', foreign_key: :parent_id, dependent: :destroy
    has_many :media, class_name: 'Pwb::Media', foreign_key: :folder_id, dependent: :nullify

    # Validations
    validates :name, presence: true
    validates :slug, uniqueness: { scope: :website_id }, allow_blank: true
    validate :parent_belongs_to_same_website
    validate :prevent_circular_reference

    # Callbacks
    before_validation :generate_slug

    # Scopes
    scope :root, -> { where(parent_id: nil) }
    scope :ordered, -> { order(:sort_order, :name) }

    # Get the full path of folder names
    def path
      ancestors.reverse.push(self).map(&:name).join(' / ')
    end

    # Get all ancestor folders
    def ancestors
      result = []
      current = parent
      while current
        result << current
        current = current.parent
      end
      result
    end

    # Get all descendant folders (recursive)
    def descendants
      result = []
      children.each do |child|
        result << child
        result.concat(child.descendants)
      end
      result
    end

    # Count media in this folder and all subfolders
    def total_media_count
      media.count + children.sum(&:total_media_count)
    end

    # Check if folder is empty (no media and no subfolders)
    def empty?
      media.empty? && children.empty?
    end

    private

    def generate_slug
      return if slug.present?
      
      self.slug = name.parameterize if name.present?
    end

    def parent_belongs_to_same_website
      return unless parent.present?
      
      unless parent.website_id == website_id
        errors.add(:parent, "must belong to the same website")
      end
    end

    def prevent_circular_reference
      return unless parent.present? && persisted?
      
      if parent_id == id || descendants.map(&:id).include?(parent_id)
        errors.add(:parent, "cannot create circular folder reference")
      end
    end
  end
end
