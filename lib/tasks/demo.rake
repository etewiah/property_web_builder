namespace :demo do
  desc 'Provision all demo websites on the demo shard'
  task provision: :environment do
    unless defined?(DEMO_SUBDOMAINS)
      raise 'DEMO_SUBDOMAINS is not configured. See config/initializers/demo_subdomains.rb'
    end

    DEMO_SUBDOMAINS.each do |subdomain, seed_pack|
      puts "Provisioning #{subdomain} using #{seed_pack}"
      Pwb::DemoProvisioner.provision(
        subdomain: subdomain,
        seed_pack: seed_pack,
        shard: :demo
      )
    end
  end

  desc 'Reset all demo data to a fresh state'
  task reset: :environment do
    Pwb::Website.demos.on_demo_shard.find_each do |website|
      puts "Resetting #{website.subdomain}"
      website.reset_demo_data!
    end
  end
end
