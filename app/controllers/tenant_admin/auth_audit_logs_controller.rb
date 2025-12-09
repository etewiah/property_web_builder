# frozen_string_literal: true

module TenantAdmin
  class AuthAuditLogsController < TenantAdminController
    # Pagy::Method is included in TenantAdminController

    def index
      @logs = Pwb::AuthAuditLog.includes(:user).order(created_at: :desc)

      # Filter by event type
      if params[:event_type].present?
        @logs = @logs.where(event_type: params[:event_type])
      end

      # Filter by email
      if params[:email].present?
        @logs = @logs.where("email ILIKE ?", "%#{params[:email]}%")
      end

      # Filter by IP address
      if params[:ip_address].present?
        @logs = @logs.where(ip_address: params[:ip_address])
      end

      # Filter by user
      if params[:user_id].present?
        @logs = @logs.where(user_id: params[:user_id])
      end

      # Filter by date range
      if params[:date_from].present?
        @logs = @logs.where("created_at >= ?", params[:date_from].to_date.beginning_of_day)
      end
      if params[:date_to].present?
        @logs = @logs.where("created_at <= ?", params[:date_to].to_date.end_of_day)
      end

      @pagy, @logs = pagy(@logs, items: 50)

      # Stats for the dashboard cards
      @stats = {
        total_events: Pwb::AuthAuditLog.count,
        login_failures_24h: Pwb::AuthAuditLog.failures.where("created_at >= ?", 24.hours.ago).count,
        unique_ips_24h: Pwb::AuthAuditLog.where("created_at >= ?", 24.hours.ago).distinct.count(:ip_address),
        locked_accounts: Pwb::User.where.not(locked_at: nil).count
      }

      # Suspicious IPs (more than 10 failures in last hour)
      @suspicious_ips = Pwb::AuthAuditLog.suspicious_ips(threshold: 10, since: 1.hour.ago)
    end

    def show
      @log = Pwb::AuthAuditLog.find(params[:id])
      @related_logs = Pwb::AuthAuditLog
        .where("email = ? OR ip_address = ?", @log.email, @log.ip_address)
        .where.not(id: @log.id)
        .order(created_at: :desc)
        .limit(20)
    end

    # Show logs for a specific user
    def user_logs
      @user = Pwb::User.unscoped.find(params[:user_id])
      @logs = @user.auth_audit_logs.order(created_at: :desc)
      @pagy, @logs = pagy(@logs, items: 50)
    end

    # Show logs for a specific IP address
    def ip_logs
      @ip_address = params[:ip]
      @logs = Pwb::AuthAuditLog.for_ip(@ip_address).order(created_at: :desc)
      @pagy, @logs = pagy(@logs, items: 50)

      # Check if this IP is suspicious
      @failure_count = Pwb::AuthAuditLog.failed_attempts_for_ip(@ip_address)
    end
  end
end
