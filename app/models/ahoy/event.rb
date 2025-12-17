# frozen_string_literal: true

module Ahoy
  class Event < ::ApplicationRecord
    self.table_name = "ahoy_events"

    # Multi-tenant associations
    belongs_to :visit, class_name: "Ahoy::Visit", optional: true
    belongs_to :website, class_name: "Pwb::Website"

    # Tenant scoping
    scope :for_website, ->(website) { where(website: website) }

    # Time-based scopes
    scope :in_period, ->(start_date, end_date) { where(time: start_date..end_date) }
    scope :today, -> { where(time: Time.current.beginning_of_day..) }
    scope :this_week, -> { where(time: 1.week.ago..) }
    scope :this_month, -> { where(time: 1.month.ago..) }
    scope :last_n_days, ->(n) { where(time: n.days.ago..) }

    # Event type scopes
    scope :by_name, ->(name) { where(name: name) }

    # Common property website events
    scope :page_views, -> { by_name("page_viewed") }
    scope :property_views, -> { by_name("property_viewed") }
    scope :inquiries, -> { by_name("inquiry_submitted") }
    scope :searches, -> { by_name("property_searched") }
    scope :contact_form_opens, -> { by_name("contact_form_opened") }
    scope :gallery_views, -> { by_name("gallery_viewed") }
    scope :share_clicks, -> { by_name("property_shared") }
    scope :favorite_clicks, -> { by_name("property_favorited") }

    # Analytics helpers
    def self.count_by_name
      group(:name)
        .order("count_all DESC")
        .count
    end

    def self.by_day
      group_by_day(:time).count
    end

    def self.property_id_counts
      property_views
        .group("properties->>'property_id'")
        .order("count_all DESC")
        .count
    end

    # Get events with a specific property value
    def self.with_property(key, value)
      where("properties->>? = ?", key, value.to_s)
    end

    # Get distinct values for a property key
    def self.distinct_property_values(key)
      select("DISTINCT properties->>'#{key}' as value")
        .where("properties->>'#{key}' IS NOT NULL")
        .pluck(:value)
    end

    # Conversion funnel helper
    def self.funnel_counts(*event_names)
      event_names.index_with do |name|
        by_name(name).distinct.count(:visit_id)
      end
    end
  end
end
