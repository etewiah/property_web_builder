# frozen_string_literal: true

module TenantAdmin
  # Controller for platform ntfy notification management
  #
  # Provides:
  # - Test notification sending
  # - Platform metrics dashboard
  # - Daily summary on-demand
  #
  class PlatformNotificationsController < TenantAdminController
    # GET /tenant_admin/platform_notifications
    def index
      @metrics = calculate_metrics
      @config_status = check_configuration
    end

    # POST /tenant_admin/platform_notifications/test
    def test
      result = PlatformNtfyService.test_configuration

      if result[:success]
        flash[:notice] = "✅ #{result[:message]}. Check your ntfy app!"
      else
        flash[:alert] = "❌ #{result[:message]}"
      end

      redirect_to tenant_admin_platform_notifications_path
    end

    # POST /tenant_admin/platform_notifications/send_daily_summary
    def send_daily_summary
      metrics = calculate_metrics

      result = PlatformNtfyService.notify_daily_summary(metrics)

      if result
        flash[:notice] = "📊 Daily summary sent successfully!"
      else
        flash[:alert] = "Failed to send daily summary. Check logs."
      end

      redirect_to tenant_admin_platform_notifications_path
    end

    # POST /tenant_admin/platform_notifications/send_test_alert
    def send_test_alert
      title = params[:title].presence || "Test Alert"
      message = params[:message].presence || "This is a test alert from the admin panel"
      priority = params[:priority]&.to_i || PlatformNtfyService::PRIORITY_DEFAULT

      result = PlatformNtfyService.notify_system_alert(title, message, priority: priority)

      if result
        flash[:notice] = "🚨 Test alert sent successfully!"
      else
        flash[:alert] = "Failed to send test alert. Check logs."
      end

      redirect_to tenant_admin_platform_notifications_path
    end

    private

    def check_configuration
      credentials = Rails.application.credentials
      {
        enabled: PlatformNtfyService.enabled?,
        server_url: credentials.dig(:platform_ntfy, :server_url) || 'https://ntfy.sh',
        topic: credentials.dig(:platform_ntfy, :topic) || '(not configured)',
        has_access_token: credentials.dig(:platform_ntfy, :access_token).present?
      }
    end

    def calculate_metrics
      today = Date.current.beginning_of_day..Date.current.end_of_day
      this_week = Date.current.beginning_of_week..Date.current.end_of_week
      this_month = Date.current.beginning_of_month..Date.current.end_of_month

      {
        # Today
        signups_today: Pwb::User.where(created_at: today).count,
        websites_created_today: Pwb::Website.unscoped.where(created_at: today).count,
        subscriptions_activated_today: subscription_events_count('activated', today),
        subscriptions_canceled_today: subscription_events_count('canceled', today),

        # This week
        signups_this_week: Pwb::User.where(created_at: this_week).count,
        websites_created_this_week: Pwb::Website.unscoped.where(created_at: this_week).count,
        subscriptions_activated_this_week: subscription_events_count('activated', this_week),
        subscriptions_canceled_this_week: subscription_events_count('canceled', this_week),

        # This month
        signups_this_month: Pwb::User.where(created_at: this_month).count,
        websites_created_this_month: Pwb::Website.unscoped.where(created_at: this_month).count,
        subscriptions_activated_this_month: subscription_events_count('activated', this_month),
        subscriptions_canceled_this_month: subscription_events_count('canceled', this_month),

        # Totals
        total_users: Pwb::User.count,
        total_active_websites: Pwb::Website.unscoped.where(provisioning_state: 'live').count,
        total_active_subscriptions: Pwb::Subscription.active_subscriptions.count,
        total_trial_subscriptions: Pwb::Subscription.trialing.count,
        total_mrr_cents: Pwb::Subscription.active_subscriptions.joins(:plan).sum('pwb_plans.price_cents'),

        # Recent activity (last 24 hours)
        recent_signups: Pwb::User.where('created_at > ?', 24.hours.ago).order(created_at: :desc).limit(5),
        recent_websites: Pwb::Website.unscoped.where('created_at > ?', 24.hours.ago).order(created_at: :desc).limit(5),
        recent_subscriptions: Pwb::Subscription.where('created_at > ?', 24.hours.ago).order(created_at: :desc).limit(5)
      }
    end

    def subscription_events_count(event_type, date_range)
      Pwb::SubscriptionEvent.where(
        event_type: event_type,
        created_at: date_range
      ).count
    end
  end
end
