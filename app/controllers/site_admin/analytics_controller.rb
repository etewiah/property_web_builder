# frozen_string_literal: true

module SiteAdmin
  # AnalyticsController
  # Provides visitor analytics dashboards for website owners
  # Shows traffic, property engagement, and conversion metrics
  class AnalyticsController < SiteAdminController
    include FeatureAuthorized

    before_action -> { require_feature("analytics") }
    before_action :set_period

    def show
      @analytics = analytics_service
      @overview = @analytics.overview

      # Charts data
      @visits_chart = @analytics.visits_by_day
      @traffic_sources = @analytics.traffic_by_source_type
      @device_breakdown = @analytics.device_breakdown
    end

    def traffic
      @analytics = analytics_service

      @visits_by_day = @analytics.visits_by_day
      @visitors_by_day = @analytics.visitors_by_day
      @traffic_sources = @analytics.traffic_sources
      @utm_campaigns = @analytics.utm_campaigns
      @geographic = @analytics.visitors_by_country
    end

    def properties
      @analytics = analytics_service

      @top_properties = @analytics.top_properties(limit: 20)
      @property_views_by_day = @analytics.property_views_by_day
      @top_searches = @analytics.top_searches
    end

    def conversions
      @analytics = analytics_service

      @funnel = @analytics.inquiry_funnel
      @conversion_rates = @analytics.funnel_conversion_rates
      @inquiries_by_day = @analytics.inquiries_by_day
    end

    def realtime
      @analytics = analytics_service

      @active_visitors = @analytics.real_time_visitors
      @recent_pageviews = @analytics.real_time_page_views

      respond_to do |format|
        format.html
        format.json do
          render json: {
            active_visitors: @active_visitors,
            recent_pageviews: @recent_pageviews
          }
        end
      end
    end

    private

    def set_period
      @period = (params[:period] || 30).to_i
      @period = 30 unless [7, 14, 30, 60, 90].include?(@period)
    end

    def analytics_service
      Pwb::AnalyticsService.new(current_website, period: @period.days)
    end
  end
end
