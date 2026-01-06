# frozen_string_literal: true

# == Schema Information
#
# Table name: pwb_support_tickets
# Database name: primary
#
#  id                         :uuid             not null, primary key
#  assigned_at                :datetime
#  category                   :string(50)
#  closed_at                  :datetime
#  description                :text
#  first_response_at          :datetime
#  last_message_at            :datetime
#  last_message_from_platform :boolean          default(FALSE)
#  message_count              :integer          default(0)
#  priority                   :integer          default("normal"), not null
#  resolved_at                :datetime
#  sla_resolution_breached    :boolean          default(FALSE)
#  sla_resolution_due_at      :datetime
#  sla_response_breached      :boolean          default(FALSE)
#  sla_response_due_at        :datetime
#  sla_warning_sent_at        :datetime
#  status                     :integer          default("open"), not null
#  subject                    :string(255)      not null
#  ticket_number              :string(20)       not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  assigned_to_id             :bigint
#  creator_id                 :bigint           not null
#  website_id                 :bigint           not null
#
# Indexes
#
#  idx_tickets_sla_response_breach_status                  (sla_response_breached,status)
#  index_pwb_support_tickets_on_assigned_to_id             (assigned_to_id)
#  index_pwb_support_tickets_on_assigned_to_id_and_status  (assigned_to_id,status)
#  index_pwb_support_tickets_on_creator_id                 (creator_id)
#  index_pwb_support_tickets_on_priority                   (priority)
#  index_pwb_support_tickets_on_sla_resolution_due_at      (sla_resolution_due_at)
#  index_pwb_support_tickets_on_sla_response_due_at        (sla_response_due_at)
#  index_pwb_support_tickets_on_status                     (status)
#  index_pwb_support_tickets_on_ticket_number              (ticket_number) UNIQUE
#  index_pwb_support_tickets_on_website_id                 (website_id)
#  index_pwb_support_tickets_on_website_id_and_created_at  (website_id,created_at)
#  index_pwb_support_tickets_on_website_id_and_status      (website_id,status)
#
# Foreign Keys
#
#  fk_rails_...  (assigned_to_id => pwb_users.id)
#  fk_rails_...  (creator_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
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

    # SLA response time targets in hours based on priority
    SLA_RESPONSE_HOURS = {
      "low" => 48,
      "normal" => 24,
      "high" => 8,
      "urgent" => 2
    }.freeze

    # SLA resolution time targets in hours based on priority
    SLA_RESOLUTION_HOURS = {
      "low" => 168,      # 7 days
      "normal" => 72,    # 3 days
      "high" => 24,      # 1 day
      "urgent" => 8      # 8 hours
    }.freeze

    # Validations
    validates :subject, presence: true, length: { maximum: 255 }
    validates :description, presence: true, on: :create
    validates :ticket_number, presence: true, uniqueness: true
    validates :category, inclusion: { in: CATEGORIES, allow_blank: true }

    # Callbacks
    before_validation :generate_ticket_number, on: :create
    after_create :create_initial_message
    after_create :set_sla_deadlines

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

    # SLA-related scopes
    scope :sla_response_at_risk, -> {
      active
        .where(first_response_at: nil)
        .where(sla_response_breached: false)
        .where("sla_response_due_at <= ?", 1.hour.from_now)
    }

    scope :sla_response_breached_pending, -> {
      active
        .where(first_response_at: nil)
        .where(sla_response_breached: false)
        .where("sla_response_due_at < ?", Time.current)
    }

    scope :sla_resolution_at_risk, -> {
      active
        .where(sla_resolution_breached: false)
        .where("sla_resolution_due_at <= ?", 2.hours.from_now)
    }

    scope :sla_resolution_breached_pending, -> {
      active
        .where(sla_resolution_breached: false)
        .where("sla_resolution_due_at < ?", Time.current)
    }

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

    # SLA Methods
    def sla_response_target_hours
      SLA_RESPONSE_HOURS[priority] || 24
    end

    def sla_resolution_target_hours
      SLA_RESOLUTION_HOURS[priority] || 72
    end

    def sla_response_met?
      return true unless sla_response_due_at
      return true if first_response_at && first_response_at <= sla_response_due_at

      !sla_response_breached? && sla_response_due_at > Time.current
    end

    def sla_resolution_met?
      return true unless sla_resolution_due_at
      return true if resolved_at && resolved_at <= sla_resolution_due_at

      !sla_resolution_breached? && sla_resolution_due_at > Time.current
    end

    def time_until_sla_breach
      return nil unless active?
      return nil if first_response_at # Already responded

      return 0 if sla_response_breached?
      return nil unless sla_response_due_at

      [sla_response_due_at - Time.current, 0].max
    end

    def time_until_sla_breach_in_words
      seconds = time_until_sla_breach
      return "Breached" if seconds.nil? || seconds <= 0

      hours = (seconds / 3600).floor
      minutes = ((seconds % 3600) / 60).floor

      if hours > 24
        days = (hours / 24).floor
        "#{days} day#{'s' if days != 1}"
      elsif hours > 0
        "#{hours} hour#{'s' if hours != 1}, #{minutes} min"
      else
        "#{minutes} minute#{'s' if minutes != 1}"
      end
    end

    def sla_status
      return :not_applicable if status_resolved? || status_closed?
      return :breached if sla_response_breached? || sla_resolution_breached?

      if sla_response_due_at && !first_response_at
        return :breached if sla_response_due_at < Time.current
        return :at_risk if sla_response_due_at <= 1.hour.from_now
      end

      if sla_resolution_due_at
        return :at_risk if sla_resolution_due_at <= 2.hours.from_now
      end

      :on_track
    end

    def sla_status_color
      case sla_status
      when :on_track then "green"
      when :at_risk then "yellow"
      when :breached then "red"
      else "gray"
      end
    end

    def mark_sla_response_breached!
      update!(sla_response_breached: true) unless sla_response_breached?
    end

    def mark_sla_resolution_breached!
      update!(sla_resolution_breached: true) unless sla_resolution_breached?
    end

    def recalculate_sla_deadlines!
      set_sla_deadlines
      save!
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

    def set_sla_deadlines
      base_time = created_at || Time.current
      self.sla_response_due_at = base_time + sla_response_target_hours.hours
      self.sla_resolution_due_at = base_time + sla_resolution_target_hours.hours
    end
  end
end
