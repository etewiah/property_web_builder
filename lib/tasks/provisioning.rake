namespace :pwb do
  namespace :provisioning do
    desc "Populate the subdomain pool with pre-generated Heroku-style names"
    task populate_subdomains: :environment do
      count = ENV.fetch('COUNT', 500).to_i
      puts "Generating #{count} subdomains..."

      created = Pwb::SubdomainGenerator.populate_pool(count: count)
      puts "Created #{created} new subdomains"
      puts "Total available: #{Pwb::Subdomain.available.count}"
    end

    desc "Ensure minimum subdomain pool size"
    task ensure_subdomain_pool: :environment do
      minimum = ENV.fetch('MINIMUM', 100).to_i
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
        puts "#{state.ljust(20)} #{count}"
      end

      puts "\n=== User Onboarding States ==="
      Pwb::User.group(:onboarding_state).count.each do |state, count|
        puts "#{state.ljust(20)} #{count}"
      end
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
