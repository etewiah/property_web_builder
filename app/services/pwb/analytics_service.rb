# frozen_string_literal: true

module Pwb
  # Service for aggregating analytics data for tenant dashboards
  #
  # Usage:
  #   analytics = Pwb::AnalyticsService.new(current_website, period: 30.days)
  #   analytics.overview        # => { total_visits: 150, unique_visitors: 120, ... }
  #   analytics.visits_by_day   # => { "2024-01-01" => 5, "2024-01-02" => 8, ... }
  #
  class AnalyticsService
    attr_reader :website, :start_date, :end_date

    def initialize(website, period: 30.days, start_date: nil, end_date: nil)
      @website = website
      @end_date = end_date || Time.current
      @start_date = start_date || @end_date - period
    end

    # Overview metrics for dashboard cards
    def overview
      {
        total_visits: visits.count,
        unique_visitors: visits.unique_visitors,
        total_pageviews: events.page_views.count,
        property_views: events.property_views.count,
        inquiries: events.inquiries.count,
        searches: events.searches.count,
        conversion_rate: conversion_rate,
        avg_pages_per_visit: avg_pages_per_visit
      }
    end

    # Comparison with previous period
    def overview_with_comparison
      current = overview
      previous_service = self.class.new(
        website,
        start_date: start_date - (end_date - start_date),
        end_date: start_date
      )
      previous = previous_service.overview

      current.transform_keys { |k| k }.merge(
        changes: calculate_changes(current, previous)
      )
    end

    # Time series data for charts
    def visits_by_day
      visits.group_by_day(:started_at).count
    end

    def visitors_by_day
      visits.group_by_day(:started_at).distinct.count(:visitor_token)
    end

    def property_views_by_day
      events.property_views.group_by_day(:time).count
    end

    def inquiries_by_day
      events.inquiries.group_by_day(:time).count
    end

    # Top content
    def top_properties(limit: 10)
      property_ids = events.property_views
        .group("properties->>'property_id'")
        .order("count_all DESC")
        .limit(limit)
        .count

      # Enrich with property data
      enrich_property_data(property_ids)
    end

    def top_pages(limit: 10)
      events.page_views
        .group("properties->>'path'")
        .order("count_all DESC")
        .limit(limit)
        .count
    end

    def top_searches(limit: 10)
      events.searches
        .group("properties->>'query'")
        .order("count_all DESC")
        .limit(limit)
        .count
    end

    # Traffic sources
    def traffic_sources(limit: 10)
      visits.group(:referring_domain)
        .order("count_all DESC")
        .limit(limit)
        .count
    end

    def traffic_by_source_type
      {
        direct: visits.direct.count,
        search: visits.from_search.count,
        social: visits.from_social.count,
        referral: visits.where.not(referring_domain: nil)
                       .where.not(referring_domain: search_domains + social_domains)
                       .count
      }
    end

    def utm_campaigns
      visits.where.not(utm_campaign: nil)
        .group(:utm_campaign)
        .order("count_all DESC")
        .count
    end

    # Geographic data
    def visitors_by_country(limit: 10)
      visits.group(:country)
        .where.not(country: nil)
        .order("count_all DESC")
        .limit(limit)
        .count
    end

    def visitors_by_city(limit: 10)
      visits.group(:city)
        .where.not(city: nil)
        .order("count_all DESC")
        .limit(limit)
        .count
    end

    # Technology
    def device_breakdown
      visits.group(:device_type).count
    end

    def browser_breakdown(limit: 5)
      visits.group(:browser)
        .order("count_all DESC")
        .limit(limit)
        .count
    end

    # Conversion funnel
    def inquiry_funnel
      {
        visits: visits.count,
        property_views: events.property_views.distinct.count(:visit_id),
        contact_opens: events.contact_form_opens.distinct.count(:visit_id),
        inquiries: events.inquiries.distinct.count(:visit_id)
      }
    end

    def funnel_conversion_rates
      funnel = inquiry_funnel
      {
        view_rate: percentage(funnel[:property_views], funnel[:visits]),
        contact_rate: percentage(funnel[:contact_opens], funnel[:property_views]),
        inquiry_rate: percentage(funnel[:inquiries], funnel[:contact_opens]),
        overall_rate: percentage(funnel[:inquiries], funnel[:visits])
      }
    end

    # Real-time (last 30 minutes)
    def real_time_visitors
      Ahoy::Visit.for_website(website)
        .where(started_at: 30.minutes.ago..)
        .distinct
        .count(:visitor_token)
    end

    def real_time_page_views
      Ahoy::Event.for_website(website)
        .page_views
        .where(time: 30.minutes.ago..)
        .count
    end

    private

    def visits
      @visits ||= Ahoy::Visit.for_website(website).in_period(start_date, end_date)
    end

    def events
      @events ||= Ahoy::Event.for_website(website).in_period(start_date, end_date)
    end

    def conversion_rate
      total = visits.count
      return 0.0 if total.zero?

      (events.inquiries.distinct.count(:visit_id).to_f / total * 100).round(2)
    end

    def avg_pages_per_visit
      total_visits = visits.count
      return 0.0 if total_visits.zero?

      (events.page_views.count.to_f / total_visits).round(2)
    end

    def percentage(numerator, denominator)
      return 0.0 if denominator.zero?
      (numerator.to_f / denominator * 100).round(2)
    end

    def calculate_changes(current, previous)
      current.except(:conversion_rate, :avg_pages_per_visit).transform_values.with_index do |(key, value), _|
        prev_value = previous[key] || 0
        next 0.0 if prev_value.zero?

        ((value - prev_value).to_f / prev_value * 100).round(1)
      end
    end

    def enrich_property_data(property_id_counts)
      return {} if property_id_counts.empty?

      ids = property_id_counts.keys.compact.map(&:to_i)
      properties = Pwb::ListedProperty.where(id: ids).index_by(&:id)

      property_id_counts.transform_keys do |id|
        next nil if id.nil?
        prop = properties[id.to_i]
        {
          id: id.to_i,
          reference: prop&.reference,
          title: prop&.title,
          price: prop&.price_current
        }
      end.compact
    end

    def search_domains
      %w[google.com bing.com yahoo.com duckduckgo.com baidu.com yandex.com]
    end

    def social_domains
      %w[facebook.com twitter.com instagram.com linkedin.com pinterest.com tiktok.com]
    end
  end
end
