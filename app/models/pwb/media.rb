# frozen_string_literal: true

module Pwb
  # Media represents a file (image, document, etc.) in the media library.
  #
  # Uses ActiveStorage for file storage with support for:
  # - Local disk storage (development)
  # - Cloudflare R2 (production)
  # - Image variants (thumbnails, optimized versions)
  #
  # Note: This model is NOT tenant-scoped. Use PwbTenant::Media for
  # tenant-scoped queries in web requests.
# == Schema Information
#
# Table name: pwb_media
#
#  id           :bigint           not null, primary key
#  alt_text     :string
#  byte_size    :bigint
#  caption      :string
#  checksum     :string
#  content_type :string
#  description  :text
#  filename     :string           not null
#  height       :integer
#  last_used_at :datetime
#  sort_order   :integer          default(0)
#  source_type  :string
#  source_url   :string
#  tags         :string           default([]), is an Array
#  title        :string
#  usage_count  :integer          default(0)
#  width        :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  folder_id    :bigint
#  website_id   :bigint           not null
#
# Indexes
#
#  index_pwb_media_on_folder_id                    (folder_id)
#  index_pwb_media_on_tags                         (tags) USING gin
#  index_pwb_media_on_website_id                   (website_id)
#  index_pwb_media_on_website_id_and_content_type  (website_id,content_type)
#  index_pwb_media_on_website_id_and_created_at    (website_id,created_at)
#  index_pwb_media_on_website_id_and_folder_id     (website_id,folder_id)
#
# Foreign Keys
#
#  fk_rails_...  (folder_id => pwb_media_folders.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
  #
  class Media < ApplicationRecord
    self.table_name = 'pwb_media'

    # Associations
    belongs_to :website, class_name: 'Pwb::Website'
    belongs_to :folder, class_name: 'Pwb::MediaFolder', optional: true
    
    # ActiveStorage attachment
    has_one_attached :file

    # Validations
    validates :filename, presence: true
    validates :file, presence: true, on: :create
    validate :acceptable_file

    # Callbacks
    before_validation :set_metadata_from_file, if: -> { file.attached? && file_changed? }
    after_commit :extract_dimensions, on: :create, if: -> { image? }

    # Scopes
    scope :images, -> { where("content_type LIKE 'image/%'") }
    scope :documents, -> { where("content_type NOT LIKE 'image/%'") }
    scope :recent, -> { order(created_at: :desc) }
    scope :by_folder, ->(folder) { folder ? where(folder: folder) : all }
    scope :search, ->(query) {
      return all if query.blank?
      where("filename ILIKE :q OR title ILIKE :q OR alt_text ILIKE :q OR description ILIKE :q",
            q: "%#{query}%")
    }
    scope :with_tag, ->(tag) { where("? = ANY(tags)", tag) }

    # Class methods
    class << self
      def allowed_content_types
        [
          # Images
          'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml',
          # Documents
          'application/pdf',
          'application/msword',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          # Text
          'text/plain', 'text/csv'
        ]
      end

      def max_file_size
        25.megabytes
      end
    end

    # Instance methods
    def image?
      content_type&.start_with?('image/')
    end

    def document?
      !image?
    end

    def pdf?
      content_type == 'application/pdf'
    end

    # Get URL for the original file
    #
    # Returns a direct CDN URL when CDN_IMAGES_URL is configured,
    # otherwise returns a Rails redirect URL.
    #
    # @return [String, nil] The URL to the original file
    def url
      return nil unless file.attached?

      # Use direct URL from storage service (respects CDN_IMAGES_URL/R2_PUBLIC_URL)
      file.url
    rescue StandardError => e
      Rails.logger.warn "Failed to generate URL for Media##{id}: #{e.message}"
      nil
    end

    # Get URL for a specific variant (images only)
    #
    # Returns a direct CDN URL for the processed variant when CDN_IMAGES_URL
    # is configured. The variant is processed on first request and cached.
    #
    # @param variant_name [Symbol] One of :thumb/:thumbnail, :small, :medium, :large
    # @return [String, nil] The URL to the variant
    def variant_url(variant_name)
      return url unless image? && file.attached?

      variant = case variant_name.to_sym
                when :thumb, :thumbnail
                  file.variant(resize_to_fill: [150, 150])
                when :small
                  file.variant(resize_to_limit: [300, 300])
                when :medium
                  file.variant(resize_to_limit: [600, 600])
                when :large
                  file.variant(resize_to_limit: [1200, 1200])
                else
                  # Return original file URL for unknown variant names
                  return url
                end

      # Process the variant and get direct CDN URL (respects CDN_IMAGES_URL/R2_PUBLIC_URL)
      variant.processed.url
    rescue StandardError => e
      Rails.logger.warn "Failed to generate variant URL for Media##{id}: #{e.message}"
      url
    end

    # Get display name (title or filename)
    def display_name
      title.presence || filename
    end

    # Format file size for display
    def human_file_size
      return nil unless byte_size
      
      ActiveSupport::NumberHelper.number_to_human_size(byte_size)
    end

    # Get dimensions as string
    def dimensions
      return nil unless width && height
      
      "#{width} x #{height}"
    end

    # Check if file is within size limit
    def within_size_limit?
      byte_size.to_i <= self.class.max_file_size
    end

    # Increment usage count
    def record_usage!
      update_columns(usage_count: usage_count + 1, last_used_at: Time.current)
    end

    # Add a tag
    def add_tag(tag)
      return if tag.blank? || tags.include?(tag)
      
      self.tags = (tags + [tag.strip.downcase]).uniq
      save
    end

    # Remove a tag
    def remove_tag(tag)
      self.tags = tags - [tag]
      save
    end

    private

    def file_changed?
      file.attachment&.new_record?
    end

    def set_metadata_from_file
      return unless file.attached?

      blob = file.blob
      self.filename = blob.filename.to_s if filename.blank?
      self.content_type = blob.content_type
      self.byte_size = blob.byte_size
      self.checksum = blob.checksum
      self.source_type ||= 'upload'
    end

    def extract_dimensions
      return unless file.attached? && image?

      file.blob.analyze unless file.blob.analyzed?
      
      if file.blob.metadata[:width] && file.blob.metadata[:height]
        update_columns(
          width: file.blob.metadata[:width],
          height: file.blob.metadata[:height]
        )
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to extract dimensions for media #{id}: #{e.message}"
    end

    def acceptable_file
      return unless file.attached?

      unless file.blob.byte_size <= self.class.max_file_size
        errors.add(:file, "is too large (maximum is #{ActiveSupport::NumberHelper.number_to_human_size(self.class.max_file_size)})")
      end

      unless self.class.allowed_content_types.include?(file.blob.content_type)
        errors.add(:file, "has an unsupported file type (#{file.blob.content_type})")
      end
    end
  end
end
