# frozen_string_literal: true

module TenantAdmin
  # Shard audit log viewing controller
  #
  # Provides read-only access to shard assignment history and audit trails.
  class ShardAuditLogsController < TenantAdminController
    # GET /tenant_admin/shard_audit_logs
    def index
      logs = Pwb::ShardAuditLog.recent.includes(:website)
      
      # Filter by status
      if params[:status].present?
        logs = logs.where(status: params[:status])
      end
      
      # Filter by date range
      if params[:from_date].present?
        logs = logs.where('created_at >= ?', params[:from_date])
      end
      
      if params[:to_date].present?
        logs = logs.where('created_at <= ?', params[:to_date])
      end
      
      @pagy, @logs = pagy(logs, limit: 50)
    end

    # GET /tenant_admin/shard_audit_logs/:id
    def show
      @log = Pwb::ShardAuditLog.includes(:website).find(params[:id])
    end

    # GET /tenant_admin/shard_audit_logs/website/:website_id
    def website_logs
      @website = Pwb::Website.unscoped.find(params[:website_id])
      logs = @website.shard_audit_logs.recent
      @pagy, @logs = pagy(logs, limit: 50)
      
      render :index
    end

    # GET /tenant_admin/shard_audit_logs/user/:email
    def user_logs
      email = params[:email]
      logs = Pwb::ShardAuditLog.by_user(email).recent.includes(:website)
      @pagy, @logs = pagy(logs, limit: 50)
      
      render :index
    end
  end
end
