# frozen_string_literal: true

namespace :external_feeds do
  desc "List all registered external feed providers"
  task providers: :environment do
    providers = Pwb::ExternalFeed::Registry.available_providers

    if providers.empty?
      puts "No providers registered."
      puts ""
      puts "Providers are registered in config/initializers/external_feeds.rb"
    else
      puts "Registered External Feed Providers:"
      puts "-" * 40

      providers.each do |name|
        provider_class = Pwb::ExternalFeed::Registry.find(name)
        display_name = provider_class.respond_to?(:display_name) ? provider_class.display_name : name.to_s.titleize

        puts "  #{name}"
        puts "    Display Name: #{display_name}"
        puts "    Class: #{provider_class.name}"
        puts ""
      end

      puts "Total: #{providers.count} provider(s)"
    end
  end

  desc "Show external feed status for all websites"
  task status: :environment do
    websites = Pwb::Website.where(external_feed_enabled: true)

    if websites.empty?
      puts "No websites have external feeds enabled."
      puts ""
      puts "Enable via: Site Admin > External Feed"
    else
      puts "Websites with External Feeds Enabled:"
      puts "-" * 60

      websites.find_each do |website|
        puts ""
        puts "#{website.subdomain}"
        puts "  Provider: #{website.external_feed_provider || 'Not set'}"
        puts "  Enabled: #{website.external_feed_enabled?}"

        if website.external_feed_provider.present?
          begin
            feed = website.external_feed
            puts "  Configured: #{feed.configured?}"
            puts "  Available: #{feed.enabled?}"
          rescue StandardError => e
            puts "  Error: #{e.message}"
          end
        end
      end

      puts ""
      puts "-" * 60
      puts "Total: #{websites.count} website(s) with feeds enabled"
    end
  end

  desc "Test external feed connection for a website"
  task :test, [:subdomain] => :environment do |_t, args|
    unless args[:subdomain]
      puts "Usage: rake external_feeds:test[subdomain]"
      puts ""
      puts "Example: rake external_feeds:test[mysite]"
      exit 1
    end

    website = Pwb::Website.find_by(subdomain: args[:subdomain])

    unless website
      puts "Error: Website '#{args[:subdomain]}' not found."
      exit 1
    end

    puts "Testing external feed for: #{website.subdomain}"
    puts "-" * 40

    unless website.external_feed_enabled?
      puts "Error: External feed is not enabled for this website."
      exit 1
    end

    unless website.external_feed_provider.present?
      puts "Error: No provider configured."
      exit 1
    end

    puts "Provider: #{website.external_feed_provider}"

    begin
      feed = website.external_feed

      puts "Configured: #{feed.configured?}"
      puts "Testing connection..."

      if feed.enabled?
        result = feed.search(page: 1, per_page: 1)

        if result.error?
          puts "Connection FAILED: #{result.error}"
          exit 1
        else
          puts "Connection SUCCESS!"
          puts "  Total properties available: #{result.total_count}"
        end
      else
        puts "Error: Provider is not available. Check configuration."
        exit 1
      end
    rescue StandardError => e
      puts "Connection FAILED: #{e.message}"
      exit 1
    end
  end

  desc "Clear external feed cache for a website (or all if no subdomain given)"
  task :clear_cache, [:subdomain] => :environment do |_t, args|
    if args[:subdomain]
      website = Pwb::Website.find_by(subdomain: args[:subdomain])

      unless website
        puts "Error: Website '#{args[:subdomain]}' not found."
        exit 1
      end

      websites = [website]
    else
      websites = Pwb::Website.where(external_feed_enabled: true)
    end

    if websites.empty?
      puts "No websites with external feeds enabled."
      exit 0
    end

    puts "Clearing external feed cache..."
    puts "-" * 40

    websites.each do |website|
      if website.external_feed_enabled? && website.external_feed_provider.present?
        begin
          website.external_feed.invalidate_cache
          puts "  #{website.subdomain}: Cache cleared"
        rescue StandardError => e
          puts "  #{website.subdomain}: Error - #{e.message}"
        end
      else
        puts "  #{website.subdomain}: Skipped (not configured)"
      end
    end

    puts ""
    puts "Done."
  end

  desc "Fetch and display sample properties from a website's feed"
  task :sample, [:subdomain, :count] => :environment do |_t, args|
    unless args[:subdomain]
      puts "Usage: rake external_feeds:sample[subdomain,count]"
      puts ""
      puts "Example: rake external_feeds:sample[mysite,5]"
      exit 1
    end

    website = Pwb::Website.find_by(subdomain: args[:subdomain])

    unless website
      puts "Error: Website '#{args[:subdomain]}' not found."
      exit 1
    end

    count = (args[:count] || 5).to_i

    puts "Fetching #{count} sample properties for: #{website.subdomain}"
    puts "-" * 60

    unless website.external_feed_enabled? && website.external_feed_provider.present?
      puts "Error: External feed not configured for this website."
      exit 1
    end

    begin
      feed = website.external_feed
      result = feed.search(page: 1, per_page: count)

      if result.error?
        puts "Error: #{result.error}"
        exit 1
      end

      puts "Found #{result.total_count} total properties"
      puts ""

      result.properties.each_with_index do |prop, idx|
        puts "#{idx + 1}. #{prop.title}"
        puts "   Reference: #{prop.reference}"
        puts "   Type: #{prop.property_type}"
        puts "   Location: #{[prop.city, prop.region].compact.join(', ')}"
        puts "   Price: #{prop.currency} #{prop.price / 100.0}"
        puts "   Beds/Baths: #{prop.bedrooms} / #{prop.bathrooms}"
        puts "   Images: #{prop.images&.count || 0}"
        puts ""
      end
    rescue StandardError => e
      puts "Error: #{e.message}"
      exit 1
    end
  end

  desc "Show feed configuration for a website"
  task :config, [:subdomain] => :environment do |_t, args|
    unless args[:subdomain]
      puts "Usage: rake external_feeds:config[subdomain]"
      exit 1
    end

    website = Pwb::Website.find_by(subdomain: args[:subdomain])

    unless website
      puts "Error: Website '#{args[:subdomain]}' not found."
      exit 1
    end

    puts "External Feed Configuration: #{website.subdomain}"
    puts "-" * 40
    puts "Enabled: #{website.external_feed_enabled?}"
    puts "Provider: #{website.external_feed_provider || 'Not set'}"
    puts ""

    if website.external_feed_config.present?
      puts "Configuration:"
      website.external_feed_config.each do |key, value|
        # Mask sensitive values
        is_sensitive = %w[api_key password secret token].any? { |s| key.to_s.include?(s) }
        display_value = if is_sensitive && value.to_s.length > 4
                          "#{value[0..3]}#{'*' * (value.length - 4)}"
                        elsif is_sensitive
                          '****'
                        else
                          value
                        end
        puts "  #{key}: #{display_value}"
      end
    else
      puts "Configuration: (none)"
    end
  end
end
