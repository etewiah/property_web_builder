# frozen_string_literal: true

namespace :hpg do
  desc 'Migrate all games from legacy HPG backend. Usage: rails hpg:migrate_legacy[subdomain]'
  task :migrate_legacy, [:subdomain] => :environment do |_t, args|
    subdomain = args[:subdomain]
    abort 'Usage: rails hpg:migrate_legacy[subdomain]' if subdomain.blank?

    website = Pwb::Website.find_by(subdomain: subdomain)
    abort "Website not found for subdomain: #{subdomain}" unless website

    scoot_slug = ENV.fetch('HPG_SCOOT_SLUG', subdomain)
    puts "Migrating legacy HPG games for #{subdomain} (scoot: #{scoot_slug})..."

    importer = Pwb::Hpg::LegacyImporter.new(website)
    importer.import_all_games(scoot_slug)
  end

  desc 'Migrate a single game from legacy HPG backend. Usage: rails hpg:migrate_game[subdomain,game-slug]'
  task :migrate_game, [:subdomain, :slug] => :environment do |_t, args|
    subdomain = args[:subdomain]
    slug = args[:slug]
    abort 'Usage: rails hpg:migrate_game[subdomain,game-slug]' if subdomain.blank? || slug.blank?

    website = Pwb::Website.find_by(subdomain: subdomain)
    abort "Website not found for subdomain: #{subdomain}" unless website

    puts "Migrating legacy HPG game '#{slug}' for #{subdomain}..."

    importer = Pwb::Hpg::LegacyImporter.new(website)
    importer.import_game(slug)
  end
end
