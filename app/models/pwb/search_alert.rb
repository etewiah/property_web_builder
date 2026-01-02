# frozen_string_literal: true

module Pwb
  # Tracks individual search alert executions and email delivery.
  # Each time a saved search is run and finds new properties,
  # a SearchAlert record is created to track the notification.
  class SearchAlert < ApplicationRecord
    self.table_name = "pwb_search_alerts"

    # Associations
    belongs_to :saved_search

    # Delegations
    delegate :website, :email, to: :saved_search

    # Validations
    validates :properties_count, numericality: { greater_than_or_equal_to: 0 }

    # Scopes
    scope :recent, -> { order(created_at: :desc) }
    scope :sent, -> { where.not(sent_at: nil) }
    scope :pending, -> { where(sent_at: nil, email_status: [nil, "pending"]) }
    scope :failed, -> { where(email_status: "failed") }
    scope :delivered, -> { where.not(delivered_at: nil) }

    # Status tracking
    EMAIL_STATUSES = %w[pending sent delivered bounced failed opened clicked].freeze

    # Instance methods
    def mark_sent!
      update!(
        sent_at: Time.current,
        email_status: "sent"
      )
    end

    def mark_delivered!
      update!(
        delivered_at: Time.current,
        email_status: "delivered"
      )
    end

    def mark_failed!(error_message)
      update!(
        email_status: "failed",
        error_message: error_message
      )
    end

    def mark_opened!
      update!(
        opened_at: Time.current,
        email_status: "opened"
      )
    end

    def mark_clicked!
      update!(
        clicked_at: Time.current,
        email_status: "clicked"
      )
    end

    def sent?
      sent_at.present?
    end

    def delivered?
      delivered_at.present?
    end

    def failed?
      email_status == "failed"
    end

    def properties
      new_properties || []
    end

    def property_references
      properties.map { |p| p["reference"] || p[:reference] }.compact
    end
  end
end
