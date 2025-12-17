# frozen_string_literal: true

module Ahoy
  class Visit < ::ApplicationRecord
    self.table_name = "ahoy_visits"

    # Multi-tenant associations
    belongs_to :website, class_name: "Pwb::Website"
    belongs_to :user, class_name: "Pwb::User", optional: true

    has_many :events, class_name: "Ahoy::Event", dependent: :destroy

    # Tenant scoping
    scope :for_website, ->(website) { where(website: website) }

    # Time-based scopes
    scope :in_period, ->(start_date, end_date) { where(started_at: start_date..end_date) }
    scope :today, -> { where(started_at: Time.current.beginning_of_day..) }
    scope :yesterday, -> { where(started_at: 1.day.ago.beginning_of_day..1.day.ago.end_of_day) }
    scope :this_week, -> { where(started_at: 1.week.ago..) }
    scope :this_month, -> { where(started_at: 1.month.ago..) }
    scope :last_n_days, ->(n) { where(started_at: n.days.ago..) }

    # Traffic source scopes
    scope :from_search, -> { where(referring_domain: %w[google.com bing.com yahoo.com duckduckgo.com]) }
    scope :from_social, -> { where(referring_domain: %w[facebook.com twitter.com instagram.com linkedin.com]) }
    scope :direct, -> { where(referring_domain: nil) }

    # Device scopes
    scope :desktop, -> { where(device_type: "Desktop") }
    scope :mobile, -> { where(device_type: "Mobile") }
    scope :tablet, -> { where(device_type: "Tablet") }

    # Analytics helpers
    def self.unique_visitors
      distinct.count(:visitor_token)
    end

    def self.by_day
      group_by_day(:started_at).count
    end

    def self.by_referrer
      group(:referring_domain)
        .order("count_all DESC")
        .count
    end

    def self.by_country
      group(:country)
        .order("count_all DESC")
        .count
    end

    def self.by_device
      group(:device_type).count
    end

    def self.by_browser
      group(:browser)
        .order("count_all DESC")
        .count
    end
  end
end
