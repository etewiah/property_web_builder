namespace :pwb do
  namespace :sharding do
    desc "List shard configuration, databases, and tenant counts"
    task list: :environment do
      puts format("%-10s %-25s %-12s", "Shard", "Database", "Tenants")
      puts '-' * 55

      Pwb::ShardRegistry.logical_shards.each do |logical|
        details = Pwb::ShardRegistry.describe_shard(logical)
        tenant_count = Pwb::Website.where(shard_name: logical.to_s).count
        database = details[:configured] ? details[:database] : 'not configured'
        puts format("%-10s %-25s %-12d", logical, database, tenant_count)
      end
    end

    desc "Provision a new tenant on a specific shard"
    task :provision, [:website_id, :shard_name] => :environment do |_, args|
      website = Pwb::Website.find(args[:website_id])
      target_shard = args[:shard_name].presence&.to_sym

      unless target_shard
        puts 'Usage: rake pwb:sharding:provision[website_id,shard_name]'
        next
      end

      unless Pwb::ShardRegistry.configured?(target_shard)
        puts "ERROR: Shard '#{target_shard}' is not configured in database.yml"
        next
      end

      if website.shard_name != 'default'
        puts "ERROR: Website is already on shard '#{website.shard_name}'. Migration is required to move it."
        next
      end

      website.update!(shard_name: target_shard.to_s)
      puts "Website #{website.id} (#{website.subdomain}) assigned to shard '#{target_shard}'."
      puts 'Note: This task only updates the pointer. If data exists, use pwb:sharding:migrate.'
    end

    desc "Migrate tenant data to a target shard"
    task :migrate, [:website_id, :target_shard] => :environment do |_, args|
      unless args[:website_id] && args[:target_shard]
        puts 'Usage: rake pwb:sharding:migrate[website_id,target_shard]'
        next
      end

      website = Pwb::Website.find(args[:website_id])
      target_shard = args[:target_shard].to_sym

      migrator = Pwb::TenantShardMigrator.new(website: website, target_shard: target_shard)
      migrator.call
      puts "Website #{website.id} migrated to #{target_shard}."
    rescue Pwb::TenantShardMigrator::MigrationError => e
      puts "Migration aborted: #{e.message}"
    end
  end
end
