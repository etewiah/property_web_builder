# frozen_string_literal: true

module TenantAdmin
  # Shard management dashboard controller
  #
  # Provides overview and management of database shards for platform administrators.
  # Only accessible to users listed in TENANT_ADMIN_EMAILS environment variable.
  class ShardsController < TenantAdminController
    # GET /tenant_admin/shards
    def index
      @shards = build_shard_list
      @distribution = Pwb::ShardService.shard_distribution
      @recent_logs = Pwb::ShardAuditLog.recent.limit(10)
    end

    # GET /tenant_admin/shards/:id
    def show
      @shard_name = params[:id]
      
      unless Pwb::ShardRegistry.configured?(@shard_name.to_sym)
        redirect_to tenant_admin_shards_path, alert: "Shard '#{@shard_name}' is not configured"
        return
      end
      
      @shard_info = Pwb::ShardRegistry.describe_shard(@shard_name.to_sym)
      @health = Pwb::ShardHealthCheck.check(@shard_name)
      @stats = Pwb::ShardService.shard_statistics(@shard_name)
    end

    # GET /tenant_admin/shards/:id/health
    def health
      @shard_name = params[:id]
      @health = Pwb::ShardHealthCheck.check(@shard_name)
      
      respond_to do |format|
        format.html
        format.json { render json: @health }
      end
    end

    # GET /tenant_admin/shards/:id/websites
    def websites
      @shard_name = params[:id]
      websites = Pwb::Website.unscoped.where(shard_name: @shard_name)
      @pagy, @websites = pagy(websites, limit: 20)
    end

    # GET /tenant_admin/shards/:id/statistics
    def statistics
      @shard_name = params[:id]
      @stats = Pwb::ShardService.shard_statistics(@shard_name)
      
      respond_to do |format|
        format.html
        format.json { render json: @stats }
      end
    end

    # GET /tenant_admin/shards/health_summary
    def health_summary
      @health_checks = Pwb::ShardHealthCheck.check_all
      
      respond_to do |format|
        format.html
        format.json { render json: @health_checks }
      end
    end

    private

    def build_shard_list
      Pwb::ShardRegistry.logical_shards.map do |shard_name|
        info = Pwb::ShardRegistry.describe_shard(shard_name)
        health = Pwb::ShardHealthCheck.check(shard_name.to_s) if info[:configured]
        
        OpenStruct.new(
          name: shard_name.to_s,
          display_name: shard_name.to_s.titleize,
          configured: info[:configured],
          database: info[:database],
          host: info[:host],
          website_count: Pwb::Website.unscoped.where(shard_name: shard_name.to_s).count,
          health: health,
          connection_status: health&.connection_status || false,
          avg_query_ms: health&.avg_query_ms,
          database_size: health&.database_size
        )
      end
    end
  end
end
