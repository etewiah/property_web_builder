# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_ticket_messages
#
#  id                  :uuid             not null, primary key
#  content             :text             not null
#  from_platform_admin :boolean          default(FALSE)
#  internal_note       :boolean          default(FALSE)
#  status_changed_from :string(50)
#  status_changed_to   :string(50)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  support_ticket_id   :uuid             not null
#  user_id             :bigint           not null
#  website_id          :bigint           not null
#
# Indexes
#
#  index_pwb_ticket_messages_on_support_ticket_id                 (support_ticket_id)
#  index_pwb_ticket_messages_on_support_ticket_id_and_created_at  (support_ticket_id,created_at)
#  index_pwb_ticket_messages_on_user_id                           (user_id)
#  index_pwb_ticket_messages_on_website_id                        (website_id)
#  index_pwb_ticket_messages_on_website_id_and_created_at         (website_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (support_ticket_id => pwb_support_tickets.id)
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
module Pwb
  class TicketMessage < ApplicationRecord
    self.table_name = "pwb_ticket_messages"

    # Associations
    belongs_to :support_ticket, class_name: "Pwb::SupportTicket"
    belongs_to :website
    belongs_to :user, class_name: "Pwb::User"

    # ActiveStorage for attachments (optional)
    has_many_attached :attachments

    # Attachment configuration
    MAX_ATTACHMENTS = 5
    MAX_ATTACHMENT_SIZE = 10.megabytes
    ALLOWED_CONTENT_TYPES = %w[
      image/jpeg image/png image/gif image/webp
      application/pdf
      text/plain text/csv
      application/msword
      application/vnd.openxmlformats-officedocument.wordprocessingml.document
      application/vnd.ms-excel
      application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    ].freeze

    # Validations
    validates :content, presence: true
    validate :validate_attachments

    # Callbacks
    after_create :update_ticket_counters

    # Scopes
    scope :public_messages, -> { where(internal_note: false) }
    scope :internal_notes, -> { where(internal_note: true) }
    scope :chronological, -> { order(created_at: :asc) }
    scope :reverse_chronological, -> { order(created_at: :desc) }
    scope :for_website, ->(website) { where(website_id: website.id) }

    # Instance Methods
    def status_change?
      status_changed_from.present? || status_changed_to.present?
    end

    def author_name
      user&.display_name || user&.email || "Unknown"
    end

    def visible_to?(viewing_user, is_platform_admin:)
      return true unless internal_note
      is_platform_admin
    end

    def from_customer?
      !from_platform_admin
    end

    def from_support_team?
      from_platform_admin
    end

    def has_attachments?
      attachments.attached?
    end

    def attachment_count
      attachments.count
    end

    def image_attachments
      attachments.select { |a| a.content_type.start_with?('image/') }
    end

    def document_attachments
      attachments.reject { |a| a.content_type.start_with?('image/') }
    end

    def total_attachment_size
      attachments.sum { |a| a.byte_size }
    end

    def attachment_summary
      return nil unless has_attachments?

      count = attachment_count
      "#{count} attachment#{'s' if count != 1}"
    end

    private

    def validate_attachments
      return unless attachments.attached?

      if attachments.count > MAX_ATTACHMENTS
        errors.add(:attachments, "cannot exceed #{MAX_ATTACHMENTS} files")
      end

      attachments.each do |attachment|
        if attachment.byte_size > MAX_ATTACHMENT_SIZE
          errors.add(:attachments, "#{attachment.filename} is too large (max #{MAX_ATTACHMENT_SIZE / 1.megabyte}MB)")
        end

        unless ALLOWED_CONTENT_TYPES.include?(attachment.content_type)
          errors.add(:attachments, "#{attachment.filename} has an unsupported file type")
        end
      end
    end

    def update_ticket_counters
      support_ticket.update!(
        message_count: support_ticket.messages.count,
        last_message_at: created_at,
        last_message_from_platform: from_platform_admin
      )

      # Record first response time from platform
      if from_platform_admin && !internal_note && support_ticket.first_response_at.nil?
        support_ticket.update!(first_response_at: created_at)
      end
    end
  end
end
