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

    desc "Create and provision a new website on a specific shard"
    task :provision_new, [:subdomain, :shard_name] => :environment do |_, args|
      subdomain = args[:subdomain]&.strip&.downcase
      shard_name = args[:shard_name]&.strip

      unless subdomain && shard_name
        puts "Usage: rake 'pwb:sharding:provision_new[subdomain,shard_name]'"
        puts ""
        puts "Examples:"
        puts "  rake 'pwb:sharding:provision_new[brisbane,demo]'"
        puts "  rake 'pwb:sharding:provision_new[my-agency,shard_1]'"
        puts ""
        puts "Options (via ENV):"
        puts "  SITE_TYPE=residential|commercial|vacation_rental (default: residential)"
        puts "  SEED_PACK=base|residential|commercial (default: base)"
        puts "  OWNER_EMAIL=user@example.com (optional - creates owner user)"
        puts "  SKIP_PROPERTIES=true (skip seeding sample properties)"
        puts ""
        puts "Available shards:"
        Pwb::ShardRegistry.logical_shards.each do |logical|
          status = Pwb::ShardRegistry.configured?(logical) ? "configured" : "not configured"
          puts "  #{logical} (#{status})"
        end
        next
      end

      target_shard = shard_name.to_sym

      # Validate shard
      unless Pwb::ShardRegistry.configured?(target_shard)
        puts "ERROR: Shard '#{target_shard}' is not configured in database.yml"
        puts ""
        puts "Available configured shards:"
        Pwb::ShardRegistry.logical_shards.each do |logical|
          puts "  #{logical}" if Pwb::ShardRegistry.configured?(logical)
        end
        next
      end

      # Check if website already exists
      existing = Pwb::Website.find_by(subdomain: subdomain)
      if existing
        puts "ERROR: Website with subdomain '#{subdomain}' already exists (id: #{existing.id}, shard: #{existing.shard_name})"
        next
      end

      # Configuration from ENV
      site_type = ENV.fetch('SITE_TYPE', 'residential')
      seed_pack = ENV.fetch('SEED_PACK', 'base')
      owner_email = ENV['OWNER_EMAIL']
      skip_properties = ENV['SKIP_PROPERTIES'] == 'true'

      puts "\n=== Provisioning New Website ==="
      puts "Subdomain:       #{subdomain}"
      puts "Shard:           #{target_shard}"
      puts "Site type:       #{site_type}"
      puts "Seed pack:       #{seed_pack}"
      puts "Owner email:     #{owner_email || '(none)'}"
      puts "Skip properties: #{skip_properties}"
      puts "=" * 40

      ActiveRecord::Base.transaction do
        # Create owner user if email provided
        user = nil
        if owner_email.present?
          user = Pwb::User.find_or_create_by!(email: owner_email.downcase) do |u|
            u.password = SecureRandom.hex(16)
            u.onboarding_state = 'active'
          end
          puts "\nOwner user: #{user.email} (id: #{user.id})"
        end

        # Create the website
        website = Pwb::Website.new(
          subdomain: subdomain,
          site_type: site_type,
          shard_name: target_shard.to_s,
          seed_pack_name: seed_pack,
          provisioning_state: 'pending',
          owner_email: owner_email
        )

        unless website.save
          puts "ERROR: Failed to create website: #{website.errors.full_messages.join(', ')}"
          raise ActiveRecord::Rollback
        end

        puts "Website created: id=#{website.id}"

        # Create owner membership if user exists
        if user
          Pwb::UserMembership.create!(
            user: user,
            website: website,
            role: 'owner',
            active: true
          )
          user.update!(website: website)
          puts "Owner membership created"
        end

        # Provision the website
        puts "\nProvisioning website..."
        service = Pwb::ProvisioningService.new
        result = service.provision_website(website: website, skip_properties: skip_properties) do |progress|
          puts "  #{progress[:percentage]}% - #{progress[:message]}"
        end

        unless result[:success]
          puts "\nERROR: Provisioning failed: #{result[:errors].join(', ')}"
          raise ActiveRecord::Rollback
        end

        website.reload
        puts "\n=== Provisioning Complete ==="
        puts "Website ID:    #{website.id}"
        puts "Subdomain:     #{website.subdomain}"
        puts "Shard:         #{website.shard_name}"
        puts "State:         #{website.provisioning_state}"

        base_domain = ENV.fetch('BASE_DOMAIN', 'propertywebbuilder.com')
        puts "URL:           https://#{website.subdomain}.#{base_domain}"

        if website.locked_pending_email_verification?
          puts "\nNote: Website is locked pending email verification."
          puts "To go live immediately, run:"
          puts "  rake 'pwb:sharding:go_live[#{website.id}]'"
        end
      end
    rescue StandardError => e
      puts "\nERROR: #{e.message}"
      puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
    end

    desc "Force a website to go live (skip email verification)"
    task :go_live, [:website_id] => :environment do |_, args|
      unless args[:website_id]
        puts "Usage: rake 'pwb:sharding:go_live[website_id]'"
        next
      end

      website = Pwb::Website.find(args[:website_id])

      unless website.locked_pending_email_verification?
        puts "Website is not in locked state (current: #{website.provisioning_state})"
        next
      end

      website.go_live!
      puts "Website #{website.subdomain} is now live!"
    rescue AASM::InvalidTransition => e
      puts "ERROR: Cannot transition to live: #{e.message}"
    end
  end
end
