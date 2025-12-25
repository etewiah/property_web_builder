# frozen_string_literal: true

module SiteAdmin
  # ActivityLogsController
  # Shows authentication and security activity logs for the current website
  class ActivityLogsController < SiteAdminController
    def index
      logs = Pwb::AuthAuditLog.where(website: current_website).recent

      # Filter by event type
      if params[:event_type].present?
        logs = logs.where(event_type: params[:event_type])
      end

      # Filter by user
      if params[:user_id].present?
        logs = logs.where(user_id: params[:user_id])
      end

      # Filter by date range
      if params[:since].present?
        date = parse_date_filter(params[:since])
        logs = logs.where('created_at >= ?', date) if date
      end

      @pagy, @logs = pagy(logs, limit: 50)
      @event_types = Pwb::AuthAuditLog::EVENT_TYPES
      @users = current_website.users.order(:email)

      # Stats for dashboard
      @stats = {
        total_today: Pwb::AuthAuditLog.where(website: current_website).today.count,
        logins_today: Pwb::AuthAuditLog.where(website: current_website, event_type: 'login_success').today.count,
        failures_today: Pwb::AuthAuditLog.where(website: current_website).failures.today.count,
        unique_ips_today: Pwb::AuthAuditLog.where(website: current_website).today.distinct.count(:ip_address)
      }
    end

    def show
      @log = Pwb::AuthAuditLog.where(website: current_website).find(params[:id])
    end

    private

    def parse_date_filter(since)
      case since
      when '1h' then 1.hour.ago
      when '24h' then 24.hours.ago
      when '7d' then 7.days.ago
      when '30d' then 30.days.ago
      else nil
      end
    end
  end
end
