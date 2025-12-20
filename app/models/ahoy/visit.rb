# frozen_string_literal: true

# == Schema Information
#
# Table name: ahoy_visits
#
#  id               :bigint           not null, primary key
#  browser          :string
#  city             :string
#  country          :string
#  device_type      :string
#  landing_page     :text
#  os               :string
#  referrer         :text
#  referring_domain :string
#  region           :string
#  started_at       :datetime
#  utm_campaign     :string
#  utm_content      :string
#  utm_medium       :string
#  utm_source       :string
#  utm_term         :string
#  visit_token      :string
#  visitor_token    :string
#  user_id          :bigint
#  website_id       :bigint           not null
#
# Indexes
#
#  index_ahoy_visits_on_user_id                    (user_id)
#  index_ahoy_visits_on_visit_token                (visit_token) UNIQUE
#  index_ahoy_visits_on_visitor_token              (visitor_token)
#  index_ahoy_visits_on_website_id                 (website_id)
#  index_ahoy_visits_on_website_id_and_started_at  (website_id,started_at)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => pwb_users.id)
#  fk_rails_...  (website_id => pwb_websites.id)
#
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
