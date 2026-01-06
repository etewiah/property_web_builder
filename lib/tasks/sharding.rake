namespace :pwb do
  namespace :sharding do
    desc "List all configured shards and tenant counts"
    task list: :environment do
      shards = PwbTenant::ApplicationRecord.connection_handler.connection_pool_names.map { |n| n.split(":").last }
      # Filter for shards defined in our config if possible, or just used the logical names
      # Since Rails doesn't easily expose the raw config list at runtime without internal APIs,
      # we will check the ones we know about or just query websites
      
      puts "Configured Shards (from database.yml):"
      # Rough heuristic to find shard keys
      configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env)
      configs.each do |config|
        puts "- #{config.name} (DB: #{config.database})" 
      end

      puts "\nTenant Distribution:"
      Pwb::Website.group(:shard_name).count.each do |shard, count|
        puts "  #{shard || 'default'}: #{count} tenants"
      end
    end

    desc "Provision a new tenant on a specific shard"
    task :provision, [:website_id, :shard_name] => :environment do |_, args|
      website = Pwb::Website.find(args[:website_id])
      target_shard = args[:shard_name]

      if website.shard_name != "default"
        puts "ERROR: Website is already on shard '#{website.shard_name}'. Migration is required to move it."
        next
      end

      # Update the shard name
      website.update!(shard_name: target_shard)
      puts "Website #{website.id} (#{website.subdomain}) assigned to shard '#{target_shard}'."
      puts "Note: This task only updates the pointer. If data already existed, use pwb:sharding:migrate."
    end
  end
end
