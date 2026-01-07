# frozen_string_literal: true

module Pwb
  class TenantShardMigrator
    class MigrationError < StandardError; end

    BATCH_SIZE = ENV.fetch('PWB_TENANT_MIGRATION_BATCH', 500).to_i

    attr_reader :website, :target_shard, :logger

    def initialize(website:, target_shard:, logger: Rails.logger, dry_run: false)
      @website = website
      @target_shard = normalize_shard(target_shard)
      @logger = logger
      @dry_run = dry_run
    end

    def call
      validate_target!
      return if @dry_run

      ActsAsTenant.without_tenant do
        website.with_lock do
          migrate_records!
          website.update!(shard_name: target_shard.to_s)
        end
      end
    end

    private

    def migrate_records!
      source = website.database_shard
      logger.info("[TenantShardMigrator] Moving website ##{website.id} from #{source} → #{target_shard}")

      tenant_table_names.each do |table_name|
        migrated = migrate_table(table_name, source: source, target: target_shard)
        logger.info("[TenantShardMigrator] #{table_name}: migrated #{migrated} rows") if migrated.positive?
      end
    end

    def migrate_table(table_name, source:, target:)
      total = 0

      loop do
        rows = fetch_rows(table_name, source)
        break if rows.empty?

        ids = rows.map { |row| row['id'] }
        ensure_no_conflicts!(table_name, ids, target: target)
        insert_rows(table_name, rows, target)
        delete_rows(table_name, ids, source)
        total += rows.size
      end

      total
    end

    def fetch_rows(table_name, shard)
      with_connection(shard) do |connection|
        connection.select_all(<<~SQL, 'TenantShardMigrator').to_a
          SELECT *
          FROM #{connection.quote_table_name(table_name)}
          WHERE website_id = #{connection.quote(website.id)}
          ORDER BY id ASC
          LIMIT #{BATCH_SIZE}
        SQL
      end
    end

    def insert_rows(table_name, rows, shard)
      return if rows.empty?

      with_connection(shard) do |connection|
        connection.insert_all(rows, table_name)
      end
    end

    def delete_rows(table_name, ids, shard)
      return if ids.empty?

      with_connection(shard) do |connection|
        sql = <<~SQL.squish
          DELETE FROM #{connection.quote_table_name(table_name)}
          WHERE id IN (#{ids.map { |id| connection.quote(id) }.join(', ')})
        SQL
        connection.execute(sql)
      end
    end

    def ensure_no_conflicts!(table_name, ids, target:)
      return if ids.empty?

      with_connection(target) do |connection|
        sql = <<~SQL.squish
          SELECT 1 FROM #{connection.quote_table_name(table_name)}
          WHERE id IN (#{ids.map { |id| connection.quote(id) }.join(', ')})
          LIMIT 1
        SQL
        conflict = connection.select_value(sql)
        raise MigrationError, "ID conflict detected for #{table_name}" if conflict
      end
    end

    def with_connection(shard)
      PwbTenant::ApplicationRecord.connected_to(role: :writing, shard: shard) do
        yield PwbTenant::ApplicationRecord.connection
      end
    end

    def tenant_table_names
      @tenant_table_names ||= begin
        base_connection = ActiveRecord::Base.connection
        base_connection.tables
                       .reject { |table| table.in?(%w[ar_internal_metadata schema_migrations active_storage_blobs active_storage_attachments]) }
                       .select do |table|
                         base_connection.columns(table).any? { |column| column.name == 'website_id' }
                       end
      end
    end

    def validate_target!
      raise MigrationError, 'Website is already on the target shard' if website.database_shard == target_shard
      raise MigrationError, "Shard #{target_shard} is not configured" unless physical_shard_configured?(target_shard)
    end

    def physical_shard_configured?(logical_shard)
      Pwb::ShardRegistry.configured?(logical_shard)
    end

    def normalize_shard(value)
      value = value.to_sym if value.respond_to?(:to_sym)
      value || :default
    end
  end
end
