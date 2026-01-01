# frozen_string_literal: true

module Pwb
  class SupportTicket < ApplicationRecord
    self.table_name = "pwb_support_tickets"

    # Associations
    belongs_to :website
    belongs_to :creator, class_name: "Pwb::User"
    belongs_to :assigned_to, class_name: "Pwb::User", optional: true
    has_many :messages, class_name: "Pwb::TicketMessage",
             foreign_key: :support_ticket_id, dependent: :destroy

    # Enums
    enum :status, {
      open: 0,
      in_progress: 1,
      waiting_on_customer: 2,
      resolved: 3,
      closed: 4
    }, prefix: true

    enum :priority, {
      low: 0,
      normal: 1,
      high: 2,
      urgent: 3
    }, prefix: true

    # Constants
    CATEGORIES = %w[billing technical feature_request bug general].freeze

    # Validations
    validates :subject, presence: true, length: { maximum: 255 }
    validates :description, presence: true, on: :create
    validates :ticket_number, presence: true, uniqueness: true
    validates :category, inclusion: { in: CATEGORIES, allow_blank: true }

    # Callbacks
    before_validation :generate_ticket_number, on: :create
    after_create :create_initial_message

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :unassigned, -> { where(assigned_to_id: nil) }
    scope :assigned_to_user, ->(user) { where(assigned_to_id: user.id) }
    scope :active, -> { where.not(status: [:resolved, :closed]) }
    scope :needs_response, -> {
      where(status: [:open, :in_progress])
        .where(last_message_from_platform: false)
    }
    scope :for_website, ->(website) { where(website_id: website.id) }

    # Instance Methods
    def assign_to!(user)
      update!(
        assigned_to: user,
        assigned_at: Time.current,
        status: :in_progress
      )
    end

    def unassign!
      update!(assigned_to: nil, assigned_at: nil)
    end

    def resolve!
      update!(status: :resolved, resolved_at: Time.current)
    end

    def close!
      update!(status: :closed, closed_at: Time.current)
    end

    def reopen!
      update!(status: :open, resolved_at: nil, closed_at: nil)
    end

    def active?
      !status_resolved? && !status_closed?
    end

    def response_time
      return nil unless first_response_at
      first_response_at - created_at
    end

    def resolution_time
      return nil unless resolved_at
      resolved_at - created_at
    end

    def status_badge_color
      case status
      when "open" then "yellow"
      when "in_progress" then "blue"
      when "waiting_on_customer" then "purple"
      when "resolved" then "green"
      when "closed" then "gray"
      else "gray"
      end
    end

    def priority_badge_color
      case priority
      when "low" then "gray"
      when "normal" then "blue"
      when "high" then "orange"
      when "urgent" then "red"
      else "gray"
      end
    end

    private

    def generate_ticket_number
      return if ticket_number.present?

      loop do
        self.ticket_number = "TKT-#{SecureRandom.hex(4).upcase}"
        break unless self.class.exists?(ticket_number: ticket_number)
      end
    end

    def create_initial_message
      return if description.blank?

      messages.create!(
        website: website,
        user: creator,
        content: description,
        from_platform_admin: false
      )
    end
  end
end
