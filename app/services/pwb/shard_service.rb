# frozen_string_literal: true

module Pwb
  # Service for managing shard assignments
  #
  # Handles the business logic for assigning websites to database shards.
  # Validates shard configuration, checks health, and creates audit logs.
  #
  # @example Assign website to shard
  #   result = Pwb::ShardService.assign_shard(
  #     website: website,
  #     new_shard: 'shard_1',
  #     changed_by: 'admin@example.com',
  #     notes: 'Moving to dedicated shard'
  #   )
  #   
  #   if result.success?
  #     puts "Success! Moved from #{result.data[:old_shard]} to #{result.data[:new_shard]}"
  #   else
  #     puts "Failed: #{result.error}"
  #   end
  class ShardService
    # Result object for service operations
    class Result
      attr_reader :success, :error, :data
      
      def initialize(success:, error: nil, data: nil)
        @success = success
        @error = error
        @data = data
      end
      
      def success?
        @success
      end
      
      def failure?
        !@success
      end
    end
    
    # Assign website to a database shard
    #
    # This only updates the routing configuration. To migrate data,
    # use Pwb::TenantShardMigrator separately.
    #
    # @param website [Pwb::Website] The website to assign
    # @param new_shard [String] Target shard name
    # @param changed_by [String] Email of user making change
    # @param notes [String, nil] Optional notes explaining the change
    # @return [Result]
    def self.assign_shard(website:, new_shard:, changed_by:, notes: nil)
      old_shard = website.shard_name || 'default'
      
      # Validation: Check if shard is configured
      unless valid_shard?(new_shard)
        available = available_shards.join(', ')
        return Result.new(
          success: false,
          error: "Invalid shard: #{new_shard}. Available shards: #{available}"
        )
      end
      
      # Skip if already on target shard
      if old_shard == new_shard
        return Result.new(
          success: false,
          error: "Website is already on shard '#{new_shard}'"
        )
      end
      
      # Check shard health
      health = Pwb::ShardHealthCheck.check(new_shard)
      unless health.connection_status
        return Result.new(
          success: false,
          error: "Cannot assign to shard '#{new_shard}': #{health.error_message || 'Connection failed'}"
        )
      end
      
      # Update with audit log in transaction
      ActiveRecord::Base.transaction do
        website.update!(shard_name: new_shard)
        
        Pwb::ShardAuditLog.create!(
          website: website,
          old_shard_name: old_shard,
          new_shard_name: new_shard,
          changed_by_email: changed_by,
          notes: notes,
          status: 'completed'
        )
      end
      
      Result.new(
        success: true,
        data: {
          old_shard: old_shard,
          new_shard: new_shard,
          website_id: website.id
        }
      )
    rescue StandardError => e
      Rails.logger.error("Shard assignment failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      
      Result.new(
        success: false,
        error: "Failed to assign shard: #{e.message}"
      )
    end
    
    # Get list of available shards from ShardRegistry
    # @return [Array<String>]
    def self.available_shards
      Pwb::ShardRegistry.logical_shards.map(&:to_s)
    end
    
    # Get list of configured shards (actually usable)
    # @return [Array<String>]
    def self.configured_shards
      Pwb::ShardRegistry.logical_shards.select do |shard|
        Pwb::ShardRegistry.configured?(shard)
      end.map(&:to_s)
    end
    
    # Validate shard name exists and is configured
    # @param shard_name [String]
    # @return [Boolean]
    def self.valid_shard?(shard_name)
      Pwb::ShardRegistry.configured?(shard_name.to_sym)
    end
    
    # Get statistics for a shard
    # @param shard_name [String]
    # @return [Hash]
    def self.shard_statistics(shard_name)
      unless valid_shard?(shard_name)
        return { error: "Shard '#{shard_name}' is not configured" }
      end
      
      shard_sym = shard_name.to_sym
      
      PwbTenant::ApplicationRecord.connected_to(shard: shard_sym) do
        {
          shard_name: shard_name,
          website_count: Pwb::Website.unscoped.where(shard_name: shard_name).count,
          property_count: count_records('pwb_realty_assets'),
          page_count: count_records('pwb_pages'),
          database_size: database_size,
          table_count: table_count,
          index_size: index_size,
          checked_at: Time.current
        }
      end
    rescue StandardError => e
      {
        error: "Failed to get statistics: #{e.message}",
        shard_name: shard_name
      }
    end
    
    # Get shard distribution across all websites
    # @return [Hash] Shard name => count
    def self.shard_distribution
      distribution = Pwb::Website.unscoped.group(:shard_name).count
      total = Pwb::Website.unscoped.count
      
      {
        distribution: distribution,
        total: total,
        percentages: calculate_percentages(distribution, total)
      }
    end
    
    private_class_method def self.count_records(table_name)
      ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) FROM #{table_name}"
      ).first['count'].to_i
    rescue
      0
    end
    
    private_class_method def self.database_size
      result = ActiveRecord::Base.connection.execute(
        "SELECT pg_database_size(current_database())"
      )
      result.first['pg_database_size'].to_i
    rescue
      0
    end
    
    private_class_method def self.table_count
      ActiveRecord::Base.connection.tables.count
    rescue
      0
    end
    
    private_class_method def self.index_size
      result = ActiveRecord::Base.connection.execute(
        "SELECT COALESCE(SUM(pg_relation_size(indexrelid)), 0) FROM pg_index"
      )
      result.first['coalesce'].to_i
    rescue
      0
    end
    
    private_class_method def self.calculate_percentages(distribution, total)
      return {} if total.zero?
      
      distribution.transform_values do |count|
        ((count.to_f / total) * 100).round(2)
      end
    end
  end
end
