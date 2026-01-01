# frozen_string_literal: true

module Pwb
  class TicketMessage < ApplicationRecord
    self.table_name = "pwb_ticket_messages"

    # Associations
    belongs_to :support_ticket, class_name: "Pwb::SupportTicket"
    belongs_to :website
    belongs_to :user, class_name: "Pwb::User"

    # ActiveStorage for attachments (optional)
    has_many_attached :attachments

    # Validations
    validates :content, presence: true

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

    private

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
