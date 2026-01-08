# frozen_string_literal: true

module Pwb
  # Health check service for database shards
  #
  # Checks connectivity, performance, and statistics for each shard.
  # Integrates with PgHero for rich database metrics.
  #
  # @example Check single shard
  #   health = Pwb::ShardHealthCheck.check('shard_1')
  #   if health.connection_status
  #     puts "Shard is healthy: #{health.avg_query_ms}ms average query time"
  #   else
  #     puts "Shard failed: #{health.error_message}"
  #   end
  #
  # @example Check all shards
  #   all_health = Pwb::ShardHealthCheck.check_all
  #   all_health.each do |name, status|
  #     puts "#{name}: #{status.connection_status ? '✓' : '✗'}"
  #   end
  class ShardHealthCheck
    # Health status result object
    HealthStatus = Struct.new(
      :shard_name,
      :connection_status,
      :avg_query_ms,
      :active_connections,
      :database_size,
      :slow_queries_count,
      :index_hit_rate,
      :cache_hit_rate,
      :table_sizes,
      :checked_at,
      :error_message,
      keyword_init: true
    ) do
      # Is the shard healthy?
      def healthy?
        connection_status && avg_query_ms && avg_query_ms < 1000 # Less than 1 second
      end
      
      # Human-readable status
      def status_label
        return 'Unhealthy' unless connection_status
        return 'Slow' if avg_query_ms && avg_query_ms > 500
        'Healthy'
      end
      
      # Status color for UI
      def status_color
        return 'red' unless connection_status
        return 'yellow' if avg_query_ms && avg_query_ms > 500
        'green'
      end
    end
    
    # Check health of specific shard
    # @param shard_name [String] Name of the shard to check
    # @return [HealthStatus]
    def self.check(shard_name)
      shard_sym = shard_name.to_sym
      checked_at = Time.current
      
      # Validate shard is configured
      unless Pwb::ShardRegistry.configured?(shard_sym)
        return HealthStatus.new(
          shard_name: shard_name,
          connection_status: false,
          checked_at: checked_at,
          error_message: "Shard not configured in database.yml"
        )
      end
      
      begin
        PwbTenant::ApplicationRecord.connected_to(shard: shard_sym) do
          HealthStatus.new(
            shard_name: shard_name,
            connection_status: test_connection,
            avg_query_ms: measure_query_time,
            active_connections: get_connection_count,
            database_size: get_database_size,
            slow_queries_count: get_slow_queries_count,
            index_hit_rate: get_index_hit_rate,
            cache_hit_rate: get_cache_hit_rate,
            table_sizes: get_top_tables,
            checked_at: checked_at,
            error_message: nil
          )
        end
      rescue StandardError => e
        Rails.logger.error("Shard health check failed for #{shard_name}: #{e.message}")
        
        HealthStatus.new(
          shard_name: shard_name,
          connection_status: false,
          avg_query_ms: nil,
          active_connections: 0,
          database_size: 0,
          checked_at: checked_at,
          error_message: e.message
        )
      end
    end
    
    # Check all configured shards
    # @return [Hash<String, HealthStatus>] Map of shard name to health status
    def self.check_all
      Pwb::ShardRegistry.logical_shards.each_with_object({}) do |shard_name, results|
        next unless Pwb::ShardRegistry.configured?(shard_name)
        results[shard_name.to_s] = check(shard_name.to_s)
      end
    end
    
    # Quick health summary (just connection status)
    # @return [Hash<String, Boolean>] Map of shard name to connection status
    def self.quick_check_all
      check_all.transform_values(&:connection_status)
    end
    
    private_class_method def self.test_connection
      ActiveRecord::Base.connection.execute("SELECT 1").any?
    end
    
    private_class_method def self.measure_query_time
      start = Time.current
      ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM pwb_websites")
      ((Time.current - start) * 1000).round(2)
    rescue
      nil
    end
    
    private_class_method def self.get_connection_count
      if defined?(PgHero)
        PgHero.connections.count
      else
        result = ActiveRecord::Base.connection.execute(
          "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()"
        )
        result.first['count'].to_i
      end
    rescue
      0
    end
    
    private_class_method def self.get_database_size
      if defined?(PgHero)
        PgHero.database_size
      else
        result = ActiveRecord::Base.connection.execute(
          "SELECT pg_database_size(current_database())"
        )
        result.first['pg_database_size'].to_i
      end
    rescue
      0
    end
    
    private_class_method def self.get_slow_queries_count
      return nil unless defined?(PgHero)
      PgHero.slow_queries(limit: 100).count
    rescue
      nil
    end
    
    private_class_method def self.get_index_hit_rate
      return nil unless defined?(PgHero)
      rate = PgHero.index_hit_rate
      (rate * 100).round(2) if rate
    rescue
      nil
    end
    
    private_class_method def self.get_cache_hit_rate
      return nil unless defined?(PgHero)
      rate = PgHero.cache_hit_rate
      (rate * 100).round(2) if rate
    rescue
      nil
    end
    
    private_class_method def self.get_top_tables
      return nil unless defined?(PgHero)
      PgHero.relation_sizes.first(10).map do |table, size|
        { table: table, size: size }
      end
    rescue
      nil
    end
  end
end
