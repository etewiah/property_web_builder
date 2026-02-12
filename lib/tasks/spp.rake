# frozen_string_literal: true

namespace :spp do
  desc 'Provision an SPP integration for a website. Usage: rails spp:provision[my-subdomain]'
  task :provision, [:subdomain] => :environment do |_t, args|
    subdomain = args[:subdomain]
    abort 'Usage: rails spp:provision[subdomain]' if subdomain.blank?

    website = Pwb::Website.find_by(subdomain: subdomain)
    abort "Website not found for subdomain: #{subdomain}" unless website

    integration = website.integrations.find_by(category: 'spp', provider: 'single_property_pages')

    if integration
      puts "SPP integration already exists for #{subdomain}."
      puts "API Key: #{integration.credential('api_key')}"
      puts "Created: #{integration.created_at}"
      puts "Last used: #{integration.last_used_at || 'never'}"
    else
      api_key = SecureRandom.hex(32)
      integration = website.integrations.create!(
        category: 'spp',
        provider: 'single_property_pages',
        credentials: { 'api_key' => api_key },
        settings: {},
        enabled: true
      )
      puts "SPP integration created for #{subdomain}."
      puts "API Key: #{api_key}"
    end

    puts ''
    puts 'Configure SPP with these environment variables:'
    puts "  PWB_API_KEY=#{integration.credential('api_key')}"
    puts "  PWB_WEBSITE_SLUG=#{website.slug}"
    puts "  PWB_API_URL=https://#{website.subdomain}.propertywebbuilder.com"
  end
end
