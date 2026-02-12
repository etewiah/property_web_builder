# frozen_string_literal: true

namespace :hpg do
  desc 'Provision an HPG integration for a website. Usage: rails hpg:provision[my-subdomain]'
  task :provision, [:subdomain] => :environment do |_t, args|
    subdomain = args[:subdomain]
    abort 'Usage: rails hpg:provision[subdomain]' if subdomain.blank?

    website = Pwb::Website.find_by(subdomain: subdomain)
    abort "Website not found for subdomain: #{subdomain}" unless website

    integration = website.integrations.find_by(category: 'hpg', provider: 'house_price_guess')

    if integration
      puts "HPG integration already exists for #{subdomain}."
      puts "API Key: #{integration.credential('api_key')}"
      puts "Created: #{integration.created_at}"
      puts "Last used: #{integration.last_used_at || 'never'}"
    else
      api_key = SecureRandom.hex(32)
      integration = website.integrations.create!(
        category: 'hpg',
        provider: 'house_price_guess',
        credentials: { 'api_key' => api_key },
        settings: {},
        enabled: true
      )
      puts "HPG integration created for #{subdomain}."
      puts "API Key: #{api_key}"
    end

    puts ''
    puts 'Configure HPG frontend with these environment variables:'
    puts "  PWB_API_KEY=#{integration.credential('api_key')}"
    puts "  PWB_WEBSITE_SLUG=#{website.subdomain}"
    puts "  PWB_API_URL=https://#{website.subdomain}.propertywebbuilder.com"
    puts "  # HPG API base: https://#{website.subdomain}.propertywebbuilder.com/api_public/v1/hpg"
  end

  desc 'Provision HPG integrations for multiple websites. Usage: rails hpg:provision_batch[sub1,sub2,sub3]'
  task :provision_batch, [:subdomains] => :environment do |_t, args|
    subdomains = args[:subdomains]&.split(',')&.map(&:strip)
    abort 'Usage: rails hpg:provision_batch[sub1,sub2,sub3]' if subdomains.blank?

    subdomains.each do |subdomain|
      puts "--- Provisioning #{subdomain} ---"
      Rake::Task['hpg:provision'].reenable
      Rake::Task['hpg:provision'].invoke(subdomain)
      puts ''
    end
  end

  desc 'Create a sample game for a website. Usage: rails hpg:create_sample_game[my-subdomain]'
  task :create_sample_game, [:subdomain] => :environment do |_t, args|
    subdomain = args[:subdomain]
    abort 'Usage: rails hpg:create_sample_game[subdomain]' if subdomain.blank?

    website = Pwb::Website.find_by(subdomain: subdomain)
    abort "Website not found for subdomain: #{subdomain}" unless website

    game = website.realty_games.find_or_create_by!(slug: 'sample-game') do |g|
      g.title = 'Sample Price Challenge'
      g.description = 'Can you guess the property prices?'
      g.default_currency = 'EUR'
      g.active = true
    end

    # Add any properties with sale listings as game listings
    assets_with_prices = website.realty_assets
                                .joins(:sale_listings)
                                .where(pwb_sale_listings: { visible: true })
                                .distinct
                                .limit(10)

    added = 0
    assets_with_prices.each_with_index do |asset, i|
      next if game.game_listings.exists?(realty_asset: asset)

      game.game_listings.create!(
        realty_asset: asset,
        sort_order: i,
        visible: true
      )
      added += 1
    end

    puts "Game '#{game.title}' (#{game.slug}) for #{subdomain}:"
    puts "  Total listings: #{game.game_listings.count}"
    puts "  Newly added: #{added}"
    puts "  URL: /api_public/v1/hpg/games/#{game.slug}"
  end
end
