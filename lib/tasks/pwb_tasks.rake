# desc "Explaining what the task does"
# task :pwb do
#   # Task goes here
# end
require 'pwb/seeder'
require 'pwb/pages_seeder'
require 'pwb/contents_seeder'
require 'pwb/seed_runner'

# from root of engine:
# bundle exec rake app:pwb:db:seed
# from spec/dummy folder or within an app using the engine:
# bundle exec rake pwb:db:seed
#
# Environment Variables:
# ----------------------
# SKIP_PROPERTIES=true  - Skip seeding sample properties (useful for production)
# SEED_MODE=create_only|force_update|upsert - Control how existing records are handled
# DRY_RUN=true          - Preview changes without applying them
# VERBOSE=false         - Reduce output verbosity
#
# Examples:
#   rake pwb:db:seed                        # Seeds with sample properties (interactive)
#   SKIP_PROPERTIES=true rake pwb:db:seed   # Seeds without sample properties
#   SEED_MODE=create_only rake pwb:db:seed  # Only create new records, skip existing
#   SEED_MODE=force_update rake pwb:db:seed # Update existing records without prompting
#   DRY_RUN=true rake pwb:db:seed           # Preview what would be changed
#
namespace :pwb do
  namespace :db do
    desc 'Seeds the database with all seed data for the default website. Set SKIP_PROPERTIES=true to skip sample properties.'
    task seed: [:environment] do
      # Seed tenant settings with default available themes first
      # This ensures all 3 themes (default, brisbane, bologna) are available
      puts "🎨 Setting up tenant settings..."
      tenant_settings = Pwb::TenantSettings.instance
      if tenant_settings.default_available_themes.blank?
        tenant_settings.update!(default_available_themes: %w[default brisbane bologna])
        puts "   Set default available themes: default, brisbane, bologna"
      else
        puts "   Tenant settings already configured with themes: #{tenant_settings.default_available_themes.join(', ')}"
      end

      website = Pwb::Website.first || Pwb::Website.create!(subdomain: 'default', theme_name: 'default', default_currency: 'EUR', default_client_locale: 'en-UK')
      skip_properties = ENV['SKIP_PROPERTIES'].to_s.downcase == 'true'

      puts "🌱 Seeding data for website: #{website.slug || 'default'} (ID: #{website.id})"
      puts "   ⏭️  Skipping sample properties" if skip_properties

      Pwb::Seeder.seed!(website: website, skip_properties: skip_properties)
      Pwb::PagesSeeder.seed_page_parts!(website: website)
      Pwb::PagesSeeder.seed_page_basics!(website: website)
      # below need to have page_parts populated to work correctly
      Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
      
      # Associate all pages with the website to ensure GraphQL queries work correctly
      orphaned_pages = Pwb::Page.where(website_id: nil)
      if orphaned_pages.any?
        puts "🔧 Associating #{orphaned_pages.count} page(s) with website #{website.id}..."
        orphaned_pages.update_all(website_id: website.id)
        puts "✅ Pages successfully associated with website"
      end
      
      # Create an admin user for the website if none exists
      if website.users.blank?
        Pwb::User.create!(email: "admin@#{website.subdomain || 'default'}.com", password: "password", admin: true, website: website)
        puts "👤 Created admin user for website: #{website.subdomain || 'default'}"
      end
      puts "✅ Seeding complete for website: #{website.slug || 'default'}"
    end

    desc 'Seeds the database for a specific tenant/website. Usage: rake pwb:db:seed_tenant[subdomain_or_slug]. Set SKIP_PROPERTIES=true to skip sample properties.'
    task :seed_tenant, [:identifier] => [:environment] do |t, args|
      identifier = args[:identifier]
      skip_properties = ENV['SKIP_PROPERTIES'].to_s.downcase == 'true'
      
      if identifier.blank?
        puts "❌ Error: Please provide a subdomain or slug"
        puts "   Usage: rake pwb:db:seed_tenant[my-subdomain]"
        puts "   Usage: SKIP_PROPERTIES=true rake pwb:db:seed_tenant[my-subdomain]"
        exit 1
      end
      
      # Try to find by subdomain first, then by slug
      website = Pwb::Website.find_by(subdomain: identifier) || 
                Pwb::Website.find_by(slug: identifier)
      
      if website.nil?
        puts "❌ Error: No website found with subdomain or slug '#{identifier}'"
        puts "   Available websites:"
        Pwb::Website.all.each do |w|
          puts "     - slug: #{w.slug || 'nil'}, subdomain: #{w.subdomain || 'nil'}, id: #{w.id}"
        end
        exit 1
      end
      
      puts "🌱 Seeding data for tenant: #{website.subdomain || website.slug} (ID: #{website.id})"
      puts "   ⏭️  Skipping sample properties" if skip_properties
      
      # Set the current website context for multi-tenancy
      Pwb::Current.website = website
      
      Pwb::Seeder.seed!(website: website, skip_properties: skip_properties)
      Pwb::PagesSeeder.seed_page_parts!(website: website)
      Pwb::PagesSeeder.seed_page_basics!(website: website)
      Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
      
      puts "✅ Seeding complete for tenant: #{website.subdomain || website.slug}"
    end

    desc 'Seeds the database for all websites/tenants. Set SKIP_PROPERTIES=true to skip sample properties.'
    task seed_all_tenants: [:environment] do
      websites = Pwb::Website.all
      skip_properties = ENV['SKIP_PROPERTIES'].to_s.downcase == 'true'
      
      if websites.empty?
        puts "⚠️  No websites found. Creating default website..."
        websites = [Pwb::Website.first || Pwb::Website.create!(subdomain: 'default', theme_name: 'default', default_currency: 'EUR', default_client_locale: 'en-UK')]
      end
      
      puts "🌱 Seeding data for #{websites.count} website(s)..."
      puts "   ⏭️  Skipping sample properties" if skip_properties

      websites.each do |website|
        puts "\n📦 Processing website: #{website.subdomain || website.slug || 'default'} (ID: #{website.id})"
        # Set the current website context
        Pwb::Current.website = website
        Pwb::Seeder.seed!(website: website, skip_properties: skip_properties)
        Pwb::PagesSeeder.seed_page_parts!(website: website)
        Pwb::PagesSeeder.seed_page_basics!(website: website)
        Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
        # Create an admin user for the website if none exists
        if website.users.blank?
          Pwb::User.create!(email: "admin@#{website.subdomain || 'default'}.com", password: "password", admin: true, website: website)
          puts "👤 Created admin user for website: #{website.subdomain || 'default'}"
        end
        puts "   ✅ Done"
      end
      
      puts "\n✅ Seeding complete for all #{websites.count} website(s)"
    end

    desc 'Creates a new tenant website with optional seeding. Usage: rake pwb:db:create_tenant[subdomain,slug,name]. Set SKIP_PROPERTIES=true to skip sample properties.'
    task :create_tenant, [:subdomain, :slug, :name] => [:environment] do |t, args|
      subdomain = args[:subdomain]
      slug = args[:slug] || subdomain
      name = args[:name] || subdomain&.titleize
      skip_properties = ENV['SKIP_PROPERTIES'].to_s.downcase == 'true'
      
      if subdomain.blank?
        puts "❌ Error: Please provide a subdomain"
        puts "   Usage: rake pwb:db:create_tenant[my-subdomain,my-slug,My Company Name]"
        puts "   Usage: SKIP_PROPERTIES=true rake pwb:db:create_tenant[my-subdomain]"
        exit 1
      end
      
      if Pwb::Website.exists?(subdomain: subdomain)
        puts "❌ Error: A website with subdomain '#{subdomain}' already exists"
        exit 1
      end
      
      if Pwb::Website.exists?(slug: slug)
        puts "❌ Error: A website with slug '#{slug}' already exists"
        exit 1
      end
      
      puts "🏗️  Creating new tenant website..."
      puts "   Subdomain: #{subdomain}"
      puts "   Slug: #{slug}"
      puts "   Name: #{name}"
      
      website = Pwb::Website.create!(
        subdomain: subdomain,
        slug: slug,
        company_display_name: name,
        theme_name: 'default'
      )
      
      puts "✅ Website created with ID: #{website.id}"
      puts "\n🌱 Seeding data for new tenant..."
      puts "   ⏭️  Skipping sample properties" if skip_properties
      
      Pwb::Current.website = website
      
      Pwb::Seeder.seed!(website: website, skip_properties: skip_properties)
      Pwb::PagesSeeder.seed_page_parts!(website: website)
      Pwb::PagesSeeder.seed_page_basics!(website: website)
      Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
      
      puts "✅ Tenant '#{subdomain}' created and seeded successfully!"
      puts "\n   Access at: http://#{subdomain}.lvh.me:3000 (development)"
    end

    desc 'Lists all tenant websites.'
    task list_tenants: [:environment] do
      websites = Pwb::Website.all
      
      if websites.empty?
        puts "No websites found."
      else
        puts "Found #{websites.count} website(s):\n\n"
        puts "  #{'ID'.ljust(6)} #{'Subdomain'.ljust(20)} #{'Slug'.ljust(20)} #{'Name'.ljust(30)}"
        puts "  #{'-' * 76}"
        websites.each do |w|
          puts "  #{w.id.to_s.ljust(6)} #{(w.subdomain || '-').ljust(20)} #{(w.slug || '-').ljust(20)} #{(w.company_display_name || '-').ljust(30)}"
        end
      end
    end

    desc 'Seeds the database with seed data for I18n, properties and field_keys. Set SKIP_PROPERTIES=true to skip sample properties.'
    task seed_base: [:environment] do
      website = Pwb::Website.first || Pwb::Website.create!(subdomain: 'default', theme_name: 'default', default_currency: 'EUR', default_client_locale: 'en-UK')
      skip_properties = ENV['SKIP_PROPERTIES'].to_s.downcase == 'true'
      
      puts "🌱 Seeding base data..."
      puts "   ⏭️  Skipping sample properties" if skip_properties
      
      Pwb::Seeder.seed!(website: website, skip_properties: skip_properties)
    end

    desc 'Seeds the database with PropertyWebBuilder default page content seed data. Will override existing content.'
    task seed_pages: [:environment] do
      website = Pwb::Website.first || Pwb::Website.create!(subdomain: 'default', theme_name: 'default', default_currency: 'EUR', default_client_locale: 'en-UK')
      puts "🌱 Seeding pages for website: #{website.slug || 'default'} (ID: #{website.id})"
      
      p 'seed_page_parts!'
      Pwb::PagesSeeder.seed_page_parts!(website: website)
      p 'seed_page_basics!'
      Pwb::PagesSeeder.seed_page_basics!(website: website)
      # below need to have page_parts populated to work correctly
      p 'seed_page_content_translations!'
      Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
      
      # Associate all pages with the website to ensure GraphQL queries work correctly
      orphaned_pages = Pwb::Page.where(website_id: nil)
      if orphaned_pages.any?
        puts "🔧 Associating #{orphaned_pages.count} page(s) with website #{website.id}..."
        orphaned_pages.update_all(website_id: website.id)
        puts "✅ Pages successfully associated with website"
      end
    end

    # =========================================================================
    # Enhanced Seeding Tasks (using SeedRunner)
    # =========================================================================
    
    desc 'Enhanced seeding with interactive mode, dry-run support, and safety warnings. See ENV vars: SEED_MODE, DRY_RUN, SKIP_PROPERTIES, VERBOSE'
    task seed_enhanced: [:environment] do
      # Ensure tenant settings have default themes
      tenant_settings = Pwb::TenantSettings.instance
      if tenant_settings.default_available_themes.blank?
        tenant_settings.update!(default_available_themes: %w[default brisbane bologna])
      end

      website = Pwb::Website.first || Pwb::Website.create!(subdomain: 'default', theme_name: 'default', default_currency: 'EUR', default_client_locale: 'en-UK')
      
      mode = parse_seed_mode(ENV['SEED_MODE'])
      dry_run = ENV['DRY_RUN'].to_s.downcase == 'true'
      skip_properties = ENV['SKIP_PROPERTIES'].to_s.downcase == 'true'
      verbose = ENV['VERBOSE'].to_s.downcase != 'false'
      
      Pwb::SeedRunner.run(
        website: website,
        mode: mode,
        dry_run: dry_run,
        skip_properties: skip_properties,
        verbose: verbose
      )
    end

    desc 'Enhanced seeding for a specific tenant. Usage: rake pwb:db:seed_tenant_enhanced[subdomain]. See ENV vars for options.'
    task :seed_tenant_enhanced, [:identifier] => [:environment] do |t, args|
      identifier = args[:identifier]
      
      if identifier.blank?
        puts "❌ Error: Please provide a subdomain or slug"
        puts "   Usage: rake pwb:db:seed_tenant_enhanced[my-subdomain]"
        puts ""
        puts "   Environment variables:"
        puts "     SEED_MODE=interactive|create_only|force_update|upsert"
        puts "     DRY_RUN=true          - Preview changes without applying"
        puts "     SKIP_PROPERTIES=true  - Skip sample properties"
        puts "     VERBOSE=false         - Reduce output"
        exit 1
      end
      
      website = Pwb::Website.find_by(subdomain: identifier) || 
                Pwb::Website.find_by(slug: identifier)
      
      if website.nil?
        puts "❌ Error: No website found with subdomain or slug '#{identifier}'"
        list_available_websites
        exit 1
      end
      
      mode = parse_seed_mode(ENV['SEED_MODE'])
      dry_run = ENV['DRY_RUN'].to_s.downcase == 'true'
      skip_properties = ENV['SKIP_PROPERTIES'].to_s.downcase == 'true'
      verbose = ENV['VERBOSE'].to_s.downcase != 'false'
      
      Pwb::SeedRunner.run(
        website: website,
        mode: mode,
        dry_run: dry_run,
        skip_properties: skip_properties,
        verbose: verbose
      )
    end

    desc 'Dry-run seeding to preview what would be changed. Usage: rake pwb:db:seed_dry_run'
    task seed_dry_run: [:environment] do
      website = Pwb::Website.first
      
      if website.nil?
        puts "⚠️  No website found. A new website would be created."
        puts ""
      end
      
      Pwb::SeedRunner.run(
        website: website,
        mode: :create_only,
        dry_run: true,
        skip_properties: ENV['SKIP_PROPERTIES'].to_s.downcase == 'true',
        verbose: true
      )
    end

    desc 'Validate seed files without running them'
    task validate_seeds: [:environment] do
      puts "📋 Validating seed files..."
      puts ""
      
      seed_dir = Rails.root.join("db", "yml_seeds")
      
      required_files = %w[
        agency.yml agency_address.yml website.yml field_keys.yml
        users.yml contacts.yml links.yml
      ]
      
      prop_files = %w[
        prop/villa_for_sale.yml prop/villa_for_rent.yml
        prop/flat_for_sale.yml prop/flat_for_rent.yml
        prop/flat_for_sale_2.yml prop/flat_for_rent_2.yml
      ]
      
      all_valid = true
      
      (required_files + prop_files).each do |file|
        path = seed_dir.join(file)
        
        if File.exist?(path)
          begin
            data = YAML.load_file(path)
            if data.nil? || (data.is_a?(Array) && data.empty?)
              puts "⚠️  #{file} - Empty or nil content"
            else
              record_count = data.is_a?(Array) ? data.count : 1
              puts "✓  #{file} - Valid (#{record_count} record(s))"
            end
          rescue Psych::SyntaxError => e
            puts "❌ #{file} - YAML syntax error: #{e.message}"
            all_valid = false
          rescue => e
            puts "❌ #{file} - Error: #{e.message}"
            all_valid = false
          end
        else
          puts "❌ #{file} - File not found"
          all_valid = false if required_files.include?(file)
        end
      end
      
      puts ""
      if all_valid
        puts "✅ All required seed files are valid"
      else
        puts "❌ Some seed files have issues"
        exit 1
      end
    end
  end
end

# Helper methods for rake tasks
def parse_seed_mode(mode_string)
  case mode_string.to_s.downcase
  when 'create_only', 'create'
    :create_only
  when 'force_update', 'update', 'force'
    :force_update
  when 'upsert'
    :upsert
  else
    :interactive
  end
end

def list_available_websites
  puts "   Available websites:"
  Pwb::Website.all.each do |w|
    puts "     - slug: #{w.slug || 'nil'}, subdomain: #{w.subdomain || 'nil'}, id: #{w.id}"
  end
end

namespace :pwb do
  namespace :website do
    desc 'Show website rendering mode info. Usage: rake pwb:website:rendering_info'
    task rendering_info: [:environment] do
      website = Pwb::Website.first

      if website.nil?
        puts "❌ No website found"
        exit 1
      end

      puts "Website Rendering Info"
      puts "=" * 40
      puts "ID:                  #{website.id}"
      puts "Subdomain:           #{website.subdomain || 'nil'}"
      puts "rendering_mode:      #{website.rendering_mode}"
      puts "client_rendering?:   #{website.client_rendering?}"
      puts "rails_rendering?:    #{website.rails_rendering?}"
      puts "client_theme_name:   #{website.client_theme_name || 'nil'}"
      puts ""
      puts "Available client themes:"
      Pwb::ClientTheme.enabled.each do |theme|
        puts "  - #{theme.name} (#{theme.friendly_name})"
      end
    end

    desc 'Set website to client rendering mode. Usage: rake pwb:website:set_client_rendering[theme_name]'
    task :set_client_rendering, [:theme_name] => [:environment] do |t, args|
      theme_name = args[:theme_name]
      website = Pwb::Website.first

      if website.nil?
        puts "❌ No website found"
        exit 1
      end

      if theme_name.blank?
        puts "❌ Please provide a client theme name"
        puts "   Usage: rake pwb:website:set_client_rendering[theme_name]"
        puts ""
        puts "   Available themes:"
        Pwb::ClientTheme.enabled.each do |theme|
          puts "     - #{theme.name}"
        end
        exit 1
      end

      theme = Pwb::ClientTheme.enabled.find_by(name: theme_name)
      if theme.nil?
        puts "❌ Client theme '#{theme_name}' not found or not enabled"
        puts "   Available themes:"
        Pwb::ClientTheme.enabled.each do |t|
          puts "     - #{t.name}"
        end
        exit 1
      end

      puts "Setting website to client rendering mode with theme '#{theme_name}'..."

      website.rendering_mode = 'client'
      website.client_theme_name = theme_name

      if website.save
        puts "✅ Website updated successfully!"
        puts "   rendering_mode:     #{website.rendering_mode}"
        puts "   client_theme_name:  #{website.client_theme_name}"
        puts "   client_rendering?:  #{website.client_rendering?}"
      else
        puts "❌ Failed to update website:"
        website.errors.full_messages.each do |msg|
          puts "   - #{msg}"
        end
        exit 1
      end
    end

    desc 'Set website to Rails rendering mode. Usage: rake pwb:website:set_rails_rendering'
    task set_rails_rendering: [:environment] do
      website = Pwb::Website.first

      if website.nil?
        puts "❌ No website found"
        exit 1
      end

      puts "Setting website to Rails rendering mode..."

      website.rendering_mode = 'rails'

      if website.save
        puts "✅ Website updated successfully!"
        puts "   rendering_mode:     #{website.rendering_mode}"
        puts "   rails_rendering?:   #{website.rails_rendering?}"
      else
        puts "❌ Failed to update website:"
        website.errors.full_messages.each do |msg|
          puts "   - #{msg}"
        end
        exit 1
      end
    end

    # =========================================================================
    # Flexible Rendering Pipeline Tasks (with subdomain parameter)
    # =========================================================================
    #
    # These tasks allow targeting a specific website by subdomain.
    # Useful for multi-tenant environments where you need to update
    # a specific website's rendering mode.
    #
    # Examples:
    #   rake pwb:website:rendering[mysite]
    #   rake pwb:website:set_rendering[mysite,client,amsterdam]
    #   rake pwb:website:set_rendering[mysite,rails]
    # =========================================================================

    desc 'Show rendering info for a specific website. Usage: rake pwb:website:rendering[subdomain]'
    task :rendering, [:subdomain] => [:environment] do |_t, args|
      subdomain = args[:subdomain]

      if subdomain.blank?
        puts "Usage: rake pwb:website:rendering[subdomain]"
        puts ""
        puts "Available websites:"
        Pwb::Website.unscoped.order(:subdomain).each do |w|
          mode_indicator = w.client_rendering? ? "[CLIENT]" : "[RAILS]"
          puts "  #{mode_indicator} #{w.subdomain || '(no subdomain)'} (ID: #{w.id})"
        end
        exit 0
      end

      website = Pwb::Website.unscoped.find_by(subdomain: subdomain)

      if website.nil?
        puts "❌ Website with subdomain '#{subdomain}' not found"
        puts ""
        puts "Available websites:"
        Pwb::Website.unscoped.order(:subdomain).limit(10).each do |w|
          puts "  - #{w.subdomain || '(no subdomain)'}"
        end
        exit 1
      end

      puts ""
      puts "Rendering Pipeline Info"
      puts "=" * 50
      puts "Website:             #{website.subdomain} (ID: #{website.id})"
      puts "Company:             #{website.company_display_name || 'N/A'}"
      puts "-" * 50
      puts "Rendering Mode:      #{website.rendering_mode.upcase}"
      puts "Client Rendering?:   #{website.client_rendering?}"
      puts "Rails Rendering?:    #{website.rails_rendering?}"
      puts "-" * 50

      if website.client_rendering?
        puts "Client Theme:        #{website.client_theme_name || 'NOT SET'}"
        if website.client_theme_config.present?
          puts "Astro Client URL:    #{website.client_theme_config['astro_client_url'] || 'default'}"
        end
      else
        puts "Rails Theme:         #{website.theme_name || 'default'}"
        puts "Selected Palette:    #{website.selected_palette || 'default'}"
      end

      puts "-" * 50
      puts "Mode Locked?:        #{website.rendering_mode_locked?}"
      if website.rendering_mode_locked?
        puts "  (Cannot change mode - website has content)"
      end

      puts ""
      puts "Available Client Themes:"
      Pwb::ClientTheme.enabled.each do |theme|
        marker = theme.name == website.client_theme_name ? " ← current" : ""
        puts "  - #{theme.name} (#{theme.friendly_name})#{marker}"
      end

      puts ""
      puts "Available Rails Themes:"
      Pwb::Theme.enabled.first(10).each do |theme|
        marker = theme.name == website.theme_name ? " ← current" : ""
        puts "  - #{theme.name} (#{theme.friendly_name})#{marker}"
      end
    end

    desc 'Set rendering mode for a specific website. Usage: rake pwb:website:set_rendering[subdomain,mode,theme_name]'
    task :set_rendering, [:subdomain, :mode, :theme_name] => [:environment] do |_t, args|
      subdomain = args[:subdomain]
      mode = args[:mode]
      theme_name = args[:theme_name]

      # Validate arguments
      if subdomain.blank? || mode.blank?
        puts "Usage: rake pwb:website:set_rendering[subdomain,mode,theme_name]"
        puts ""
        puts "Arguments:"
        puts "  subdomain   - Website subdomain (required)"
        puts "  mode        - 'client' or 'rails' (required)"
        puts "  theme_name  - Theme name (required for client mode, optional for rails)"
        puts ""
        puts "Examples:"
        puts "  rake pwb:website:set_rendering[mysite,client,amsterdam]"
        puts "  rake pwb:website:set_rendering[mysite,rails]"
        puts "  rake pwb:website:set_rendering[mysite,rails,starter]"
        exit 1
      end

      # Find website
      website = Pwb::Website.unscoped.find_by(subdomain: subdomain)
      if website.nil?
        puts "❌ Website with subdomain '#{subdomain}' not found"
        exit 1
      end

      # Validate mode
      unless %w[client rails].include?(mode)
        puts "❌ Invalid mode '#{mode}'. Must be 'client' or 'rails'"
        exit 1
      end

      # Check if mode is locked
      if website.rendering_mode_locked? && website.rendering_mode != mode
        puts "❌ Cannot change rendering mode for '#{subdomain}'"
        puts "   Website has content and mode is locked to: #{website.rendering_mode}"
        puts ""
        puts "   To force change (may cause issues), use rails console:"
        puts "   Pwb::Website.find_by(subdomain: '#{subdomain}').update_column(:rendering_mode, '#{mode}')"
        exit 1
      end

      puts ""
      puts "Updating Rendering Pipeline"
      puts "=" * 50
      puts "Website:         #{subdomain}"
      puts "Current Mode:    #{website.rendering_mode}"
      puts "New Mode:        #{mode}"

      # Set mode and theme
      website.rendering_mode = mode

      if mode == 'client'
        if theme_name.blank?
          puts ""
          puts "❌ Client mode requires a theme_name"
          puts ""
          puts "Available client themes:"
          Pwb::ClientTheme.enabled.each do |t|
            puts "  - #{t.name}"
          end
          exit 1
        end

        theme = Pwb::ClientTheme.enabled.find_by(name: theme_name)
        if theme.nil?
          puts ""
          puts "❌ Client theme '#{theme_name}' not found"
          puts ""
          puts "Available client themes:"
          Pwb::ClientTheme.enabled.each do |t|
            puts "  - #{t.name}"
          end
          exit 1
        end

        website.client_theme_name = theme_name
        puts "Client Theme:    #{theme_name}"
      else
        # Rails mode
        if theme_name.present?
          theme = Pwb::Theme.enabled.find { |t| t.name == theme_name }
          if theme.nil?
            puts ""
            puts "⚠️  Warning: Rails theme '#{theme_name}' not found, using anyway"
          end
          website.theme_name = theme_name
          puts "Rails Theme:     #{theme_name}"
        end
      end

      puts "-" * 50

      if website.save
        puts "✅ Successfully updated!"
        puts ""
        puts "New settings:"
        puts "  rendering_mode:      #{website.rendering_mode}"
        if website.client_rendering?
          puts "  client_theme_name:   #{website.client_theme_name}"
        else
          puts "  theme_name:          #{website.theme_name}"
        end
      else
        puts "❌ Failed to update website:"
        website.errors.full_messages.each do |msg|
          puts "   - #{msg}"
        end
        exit 1
      end
    end

    desc 'List all websites with their rendering modes. Usage: rake pwb:website:list_rendering'
    task list_rendering: [:environment] do
      websites = Pwb::Website.unscoped.order(:subdomain)

      if websites.empty?
        puts "No websites found"
        exit 0
      end

      puts ""
      puts "Website Rendering Modes"
      puts "=" * 80
      puts format("%-25s %-10s %-20s %-15s", "SUBDOMAIN", "MODE", "THEME", "LOCKED?")
      puts "-" * 80

      websites.each do |w|
        subdomain = w.subdomain || "(no subdomain)"
        mode = w.rendering_mode.upcase
        theme = w.client_rendering? ? w.client_theme_name : w.theme_name
        theme ||= "default"
        locked = w.rendering_mode_locked? ? "YES" : "no"

        puts format("%-25s %-10s %-20s %-15s", subdomain.truncate(24), mode, theme.truncate(19), locked)
      end

      puts "-" * 80
      puts "Total: #{websites.count} websites"
      puts ""
      puts "Legend: MODE = RAILS (server-side) or CLIENT (Astro.js)"
    end
  end
end
