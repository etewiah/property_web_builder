namespace :pwb do
  namespace :provisioning do
    desc "Populate the subdomain pool with pre-generated Heroku-style names"
    task populate_subdomains: :environment do
      count = ENV.fetch('COUNT', 50).to_i
      puts "Generating #{count} subdomains..."

      created = Pwb::SubdomainGenerator.populate_pool(count: count)
      puts "Created #{created} new subdomains"
      puts "Total available: #{Pwb::Subdomain.available.count}"
    end

    desc "Ensure minimum subdomain pool size"
    task ensure_subdomain_pool: :environment do
      minimum = ENV.fetch('MINIMUM', 10).to_i
      puts "Ensuring at least #{minimum} subdomains are available..."

      Pwb::SubdomainGenerator.ensure_pool_minimum(minimum: minimum)
      puts "Available subdomains: #{Pwb::Subdomain.available.count}"
    end

    desc "Release expired subdomain reservations"
    task release_expired: :environment do
      expired_count = Pwb::Subdomain.expired_reservations.count
      puts "Found #{expired_count} expired reservations"

      Pwb::Subdomain.release_expired!
      puts "Released all expired reservations"
    end

    desc "Show subdomain pool statistics"
    task stats: :environment do
      puts "\n=== Subdomain Pool Statistics ==="
      puts "Available:  #{Pwb::Subdomain.available.count}"
      puts "Reserved:   #{Pwb::Subdomain.reserved.count}"
      puts "Allocated:  #{Pwb::Subdomain.allocated.count}"
      puts "Released:   #{Pwb::Subdomain.where(aasm_state: 'released').count}"
      puts "Total:      #{Pwb::Subdomain.count}"

      expired = Pwb::Subdomain.expired_reservations.count
      puts "\nExpired reservations: #{expired}" if expired > 0

      puts "\n=== Website Provisioning States ==="
      Pwb::Website.group(:provisioning_state).count.each do |state, count|
        puts "#{state.to_s.ljust(20)} #{count}"
      end

      puts "\n=== User Onboarding States ==="
      Pwb::User.group(:onboarding_state).count.each do |state, count|
        next if state.nil?
        puts "#{state.to_s.ljust(20)} #{count}"
      end
    end

    # =========================================================================
    # Subdomain Listing Tasks
    # =========================================================================

    desc "List available subdomains (use LIMIT=n to limit results)"
    task list_available: :environment do
      limit = ENV.fetch('LIMIT', 50).to_i
      subdomains = Pwb::Subdomain.available.order(:name).limit(limit).pluck(:name)

      puts "\n=== Available Subdomains (showing #{subdomains.count} of #{Pwb::Subdomain.available.count}) ==="
      subdomains.each { |name| puts "  #{name}" }
      puts "\nUse LIMIT=100 to show more, or LIMIT=0 for all"
    end

    desc "List reserved subdomains with reservation details"
    task list_reserved: :environment do
      reserved = Pwb::Subdomain.reserved.order(:reserved_at)

      puts "\n=== Reserved Subdomains (#{reserved.count} total) ==="
      if reserved.any?
        reserved.each do |sub|
          expires_in = sub.reserved_until ? ((sub.reserved_until - Time.current) / 60).round : 'N/A'
          status = sub.reserved_until && sub.reserved_until < Time.current ? '(EXPIRED)' : ''
          puts "  #{sub.name.ljust(25)} #{sub.reserved_by_email.to_s.ljust(30)} expires in #{expires_in} min #{status}"
        end
      else
        puts "  No reserved subdomains"
      end
    end

    desc "List allocated subdomains with their websites"
    task list_allocated: :environment do
      allocated = Pwb::Subdomain.allocated.includes(:website).order(:name)

      puts "\n=== Allocated Subdomains (#{allocated.count} total) ==="
      if allocated.any?
        allocated.each do |sub|
          website_info = sub.website ? "#{sub.website.subdomain} (#{sub.website.provisioning_state})" : 'No website'
          puts "  #{sub.name.ljust(25)} -> #{website_info}"
        end
      else
        puts "  No allocated subdomains"
      end
    end

    desc "Search subdomains by pattern (use PATTERN=word)"
    task search: :environment do
      pattern = ENV['PATTERN']
      unless pattern
        puts "Usage: rake pwb:provisioning:search PATTERN=sunny"
        exit 1
      end

      results = Pwb::Subdomain.where("name ILIKE ?", "%#{pattern}%").order(:aasm_state, :name)

      puts "\n=== Subdomains matching '#{pattern}' (#{results.count} found) ==="
      results.each do |sub|
        status = case sub.aasm_state
                 when 'available' then '[available]'
                 when 'reserved' then "[reserved by #{sub.reserved_by_email}]"
                 when 'allocated' then "[allocated to #{sub.website&.subdomain}]"
                 else "[#{sub.aasm_state}]"
                 end
        puts "  #{sub.name.ljust(25)} #{status}"
      end
    end

    # =========================================================================
    # Website Management Tasks
    # =========================================================================

    desc "List websites by provisioning state (use STATE=live to filter)"
    task list_websites: :environment do
      state = ENV['STATE']

      websites = if state
                   Pwb::Website.where(provisioning_state: state)
                 else
                   Pwb::Website.all
                 end.order(:provisioning_state, :subdomain)

      puts "\n=== Websites #{state ? "(state: #{state})" : "(all states)"} ==="
      puts "Total: #{websites.count}\n\n"

      websites.group_by(&:provisioning_state).each do |prov_state, sites|
        puts "#{prov_state.to_s.upcase} (#{sites.count}):"
        sites.each do |site|
          owner = site.user_memberships.find_by(role: 'owner')&.user
          owner_info = owner ? owner.email : 'no owner'
          puts "  #{site.subdomain.to_s.ljust(25)} #{site.site_type.to_s.ljust(15)} #{owner_info}"
        end
        puts
      end
    end

    desc "List failed websites with error details"
    task list_failed: :environment do
      failed = Pwb::Website.where(provisioning_state: 'failed')

      puts "\n=== Failed Websites (#{failed.count} total) ==="
      if failed.any?
        failed.each do |site|
          puts "  #{site.subdomain}:"
          puts "    Error: #{site.provisioning_error || 'No error message'}"
          puts "    Started: #{site.provisioning_started_at}"
          puts
        end
      else
        puts "  No failed websites"
      end
    end

    desc "Retry provisioning for a failed website (use SUBDOMAIN=name)"
    task retry_failed: :environment do
      subdomain = ENV['SUBDOMAIN']
      unless subdomain
        puts "Usage: rake pwb:provisioning:retry_failed SUBDOMAIN=my-site"
        exit 1
      end

      website = Pwb::Website.find_by(subdomain: subdomain)
      unless website
        puts "Website '#{subdomain}' not found"
        exit 1
      end

      unless website.failed?
        puts "Website '#{subdomain}' is not in failed state (current: #{website.provisioning_state})"
        exit 1
      end

      puts "Retrying provisioning for #{subdomain}..."
      service = Pwb::ProvisioningService.new
      result = service.retry_provisioning(website: website)

      if result[:success]
        puts "Provisioning restarted successfully"
        puts "New state: #{website.reload.provisioning_state}"
      else
        puts "Failed to restart: #{result[:errors].join(', ')}"
      end
    end

    # =========================================================================
    # User Management Tasks
    # =========================================================================

    desc "List users by onboarding state (use STATE=lead to filter)"
    task list_users: :environment do
      state = ENV['STATE']

      users = if state
                Pwb::User.where(onboarding_state: state)
              else
                Pwb::User.where.not(onboarding_state: nil)
              end.order(:onboarding_state, :created_at)

      puts "\n=== Users #{state ? "(state: #{state})" : "(with onboarding state)"} ==="
      puts "Total: #{users.count}\n\n"

      users.group_by(&:onboarding_state).each do |onb_state, user_list|
        puts "#{onb_state.to_s.upcase} (#{user_list.count}):"
        user_list.first(20).each do |user|
          step_info = user.onboarding_step ? "step #{user.onboarding_step}" : ''
          puts "  #{user.email.ljust(35)} #{step_info.ljust(10)} created #{user.created_at.strftime('%Y-%m-%d')}"
        end
        puts "  ... and #{user_list.count - 20} more" if user_list.count > 20
        puts
      end
    end

    desc "List churned/abandoned signups"
    task list_churned: :environment do
      churned = Pwb::User.where(onboarding_state: 'churned').order(updated_at: :desc)
      stale_leads = Pwb::User.where(onboarding_state: 'lead')
                            .where('created_at < ?', 24.hours.ago)
                            .order(created_at: :desc)

      puts "\n=== Churned Users (#{churned.count}) ==="
      churned.first(10).each do |user|
        puts "  #{user.email.ljust(35)} churned at #{user.updated_at.strftime('%Y-%m-%d %H:%M')}"
      end

      puts "\n=== Stale Leads (>24h old, #{stale_leads.count}) ==="
      stale_leads.first(10).each do |user|
        puts "  #{user.email.ljust(35)} created #{user.created_at.strftime('%Y-%m-%d %H:%M')}"
      end
    end

    # =========================================================================
    # Cleanup Tasks
    # =========================================================================

    desc "Mark stale leads as churned (older than HOURS, default 48)"
    task cleanup_stale_leads: :environment do
      hours = ENV.fetch('HOURS', 48).to_i
      cutoff = hours.hours.ago

      stale_leads = Pwb::User.where(onboarding_state: 'lead')
                            .where('created_at < ?', cutoff)

      count = stale_leads.count
      puts "Found #{count} stale leads (older than #{hours} hours)"

      if ENV['DRY_RUN'] == 'true'
        puts "DRY RUN - no changes made"
        stale_leads.limit(10).each { |u| puts "  Would mark churned: #{u.email}" }
      else
        stale_leads.find_each do |user|
          user.mark_churned! if user.may_mark_churned?
        end
        puts "Marked #{count} leads as churned"
      end
    end

    desc "Release orphaned reserved subdomains (no matching user)"
    task cleanup_orphaned_reservations: :environment do
      orphaned = Pwb::Subdomain.reserved.select do |sub|
        sub.reserved_by_email.present? &&
        !Pwb::User.exists?(email: sub.reserved_by_email)
      end

      puts "Found #{orphaned.count} orphaned reservations"

      if ENV['DRY_RUN'] == 'true'
        puts "DRY RUN - no changes made"
        orphaned.first(10).each { |s| puts "  Would release: #{s.name} (#{s.reserved_by_email})" }
      else
        orphaned.each(&:release!)
        puts "Released #{orphaned.count} orphaned reservations"
      end
    end

    desc "Full cleanup: expired reservations, stale leads, orphaned reservations"
    task cleanup_all: :environment do
      puts "Running full cleanup..."
      puts

      Rake::Task['pwb:provisioning:release_expired'].invoke
      puts

      Rake::Task['pwb:provisioning:cleanup_stale_leads'].invoke
      puts

      Rake::Task['pwb:provisioning:cleanup_orphaned_reservations'].invoke
      puts

      puts "Cleanup complete!"
      Rake::Task['pwb:provisioning:stats'].invoke
    end

    desc "Simulate a complete provisioning flow (for testing)"
    task :simulate, [:email] => :environment do |_t, args|
      email = args[:email] || "test-#{SecureRandom.hex(4)}@example.com"

      puts "\n=== Simulating Provisioning Flow ==="
      puts "Email: #{email}\n\n"

      service = Pwb::ProvisioningService.new

      # Step 1: Start signup
      puts "Step 1: Starting signup..."
      result = service.start_signup(email: email)
      unless result[:success]
        puts "FAILED: #{result[:errors].join(', ')}"
        exit 1
      end
      user = result[:user]
      subdomain = result[:subdomain]
      puts "  User created: #{user.email} (state: #{user.onboarding_state})"
      puts "  Subdomain reserved: #{subdomain.name}"

      # Step 2: Verify email (simulated)
      puts "\nStep 2: Verifying email..."
      user.register! if user.may_register?
      result = service.verify_email(user: user.reload, token: 'test-token')
      puts "  User state: #{user.reload.onboarding_state}"

      # Step 3: Configure site
      puts "\nStep 3: Configuring site..."
      result = service.configure_site(
        user: user,
        subdomain_name: subdomain.name,
        site_type: 'residential'
      )
      unless result[:success]
        puts "FAILED: #{result[:errors].join(', ')}"
        exit 1
      end
      website = result[:website]
      puts "  Website created: #{website.subdomain} (state: #{website.provisioning_state})"

      # Step 4: Provision
      puts "\nStep 4: Provisioning website..."
      result = service.provision_website(website: website) do |progress|
        puts "  #{progress[:percentage]}% - #{progress[:message]}"
      end
      unless result[:success]
        puts "FAILED: #{result[:errors].join(', ')}"
        exit 1
      end

      puts "\n=== Provisioning Complete ==="
      website.reload
      user.reload
      puts "Website: #{website.subdomain}.#{Pwb::Website.platform_domains.first}"
      puts "Website state: #{website.provisioning_state}"
      puts "User state: #{user.onboarding_state}"
      puts "URL: #{website.primary_url}"
    end

    desc "Check subdomain availability"
    task :check_subdomain, [:name] => :environment do |_t, args|
      name = args[:name]
      unless name
        puts "Usage: rake pwb:provisioning:check_subdomain[name]"
        exit 1
      end

      result = Pwb::SubdomainGenerator.validate_custom_name(name)
      if result[:valid]
        puts "'#{result[:normalized]}' is available!"
      else
        puts "'#{name}' is NOT available:"
        result[:errors].each { |e| puts "  - #{e}" }
      end
    end

    desc "Generate a random subdomain suggestion"
    task suggest_subdomain: :environment do
      5.times do
        puts Pwb::SubdomainGenerator.generate
      end
    end
  end
end
