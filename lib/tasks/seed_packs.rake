# frozen_string_literal: true

namespace :pwb do
  namespace :seed_packs do
    desc "List all available seed packs"
    task list: :environment do
      require_relative '../pwb/seed_pack'

      puts "\nAvailable Seed Packs:"
      puts "=" * 50

      Pwb::SeedPack.available.each do |pack|
        puts "\n#{pack.display_name} (#{pack.name})"
        puts "  #{pack.description}"
        puts "  Version: #{pack.version}"
        puts "  Inherits from: #{pack.config[:inherits_from] || 'none'}"

        if pack.config[:website]
          website = pack.config[:website]
          puts "  Theme: #{website[:theme_name]}" if website[:theme_name]
          puts "  Locales: #{website[:supported_locales]&.join(', ')}" if website[:supported_locales]
          puts "  Currency: #{website[:currency]}" if website[:currency]
        end
      end

      puts "\n" + "=" * 50
      puts "Use 'rails pwb:seed_packs:apply[pack_name]' to apply a pack"
      puts "Use 'rails pwb:seed_packs:preview[pack_name]' to preview a pack"
    end

    desc "Preview what a seed pack will create (dry run)"
    task :preview, [:pack_name] => :environment do |_t, args|
      require_relative '../pwb/seed_pack'

      pack_name = args[:pack_name]
      if pack_name.blank?
        puts "Usage: rails pwb:seed_packs:preview[pack_name]"
        puts "Run 'rails pwb:seed_packs:list' to see available packs"
        exit 1
      end

      pack = Pwb::SeedPack.find(pack_name)
      if pack.nil?
        puts "Error: Pack '#{pack_name}' not found"
        puts "Run 'rails pwb:seed_packs:list' to see available packs"
        exit 1
      end

      puts "\nPreviewing Seed Pack: #{pack.display_name}"
      puts "=" * 50

      preview = pack.preview
      preview.each do |section, items|
        puts "\n#{section.to_s.titleize}:"
        if items.is_a?(Array)
          items.each { |item| puts "  - #{item}" }
        elsif items.is_a?(Hash)
          items.each { |key, value| puts "  #{key}: #{value}" }
        else
          puts "  #{items}"
        end
      end

      puts "\n" + "=" * 50
      puts "This is a preview. Use 'rails pwb:seed_packs:apply[#{pack_name}]' to apply."
    end

    desc "Apply a seed pack to a website"
    task :apply, [:pack_name, :website_id] => :environment do |_t, args|
      require_relative '../pwb/seed_pack'

      pack_name = args[:pack_name]
      website_id = args[:website_id]

      if pack_name.blank?
        puts "Usage: rails pwb:seed_packs:apply[pack_name,website_id]"
        puts "       rails pwb:seed_packs:apply[pack_name] (uses default website)"
        puts "Run 'rails pwb:seed_packs:list' to see available packs"
        exit 1
      end

      pack = Pwb::SeedPack.find(pack_name)
      if pack.nil?
        puts "Error: Pack '#{pack_name}' not found"
        exit 1
      end

      website = if website_id.present?
                  Pwb::Website.find(website_id)
                else
                  Pwb::Website.unique_instance
                end

      if website.nil?
        puts "Error: Website not found"
        exit 1
      end

      puts "\nApplying Seed Pack: #{pack.display_name}"
      puts "To Website: #{website.id}"
      puts "=" * 50

      begin
        pack.apply!(website: website)
        puts "\nSeed pack applied successfully!"
      rescue StandardError => e
        puts "\nError applying seed pack: #{e.message}"
        puts e.backtrace.first(10).join("\n") if Rails.env.development?
        exit 1
      end
    end

    desc "Apply a seed pack with options"
    task :apply_with_options, [:pack_name, :options] => :environment do |_t, args|
      require_relative '../pwb/seed_pack'

      pack_name = args[:pack_name]
      options_str = args[:options] || ""

      if pack_name.blank?
        puts "Usage: rails pwb:seed_packs:apply_with_options[pack_name,'skip_users,skip_properties']"
        puts "Available options: skip_website, skip_agency, skip_users, skip_properties, skip_content, skip_navigation"
        exit 1
      end

      pack = Pwb::SeedPack.find(pack_name)
      if pack.nil?
        puts "Error: Pack '#{pack_name}' not found"
        exit 1
      end

      options = {}
      options_str.split(',').each do |opt|
        options[opt.strip.to_sym] = true
      end

      website = Pwb::Website.unique_instance

      puts "\nApplying Seed Pack: #{pack.display_name}"
      puts "Options: #{options.keys.join(', ')}" if options.any?
      puts "=" * 50

      begin
        pack.apply!(website: website, options: options)
        puts "\nSeed pack applied successfully!"
      rescue StandardError => e
        puts "\nError applying seed pack: #{e.message}"
        puts e.backtrace.first(10).join("\n") if Rails.env.development?
        exit 1
      end
    end

    desc "Reset and apply a seed pack (WARNING: destroys existing data)"
    task :reset_and_apply, [:pack_name] => :environment do |_t, args|
      require_relative '../pwb/seed_pack'

      pack_name = args[:pack_name]

      if pack_name.blank?
        puts "Usage: rails pwb:seed_packs:reset_and_apply[pack_name]"
        exit 1
      end

      pack = Pwb::SeedPack.find(pack_name)
      if pack.nil?
        puts "Error: Pack '#{pack_name}' not found"
        exit 1
      end

      puts "\n*** WARNING ***"
      puts "This will delete all existing properties, users, and content!"
      puts "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
      sleep 5

      puts "\nResetting database..."

      # Clear existing data
      Pwb::RealtyAsset.destroy_all
      Pwb::User.where.not(email: 'admin@example.com').destroy_all
      Pwb::Content.destroy_all
      Pwb::Link.destroy_all

      website = Pwb::Website.unique_instance

      puts "Applying seed pack: #{pack.display_name}"
      pack.apply!(website: website)

      puts "\nReset and apply completed successfully!"
    end
  end
end
