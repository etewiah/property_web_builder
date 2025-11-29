# desc "Explaining what the task does"
# task :pwb do
#   # Task goes here
# end
require 'pwb/seeder'
require 'pwb/pages_seeder'
require 'pwb/contents_seeder'
# from root of engine:
# bundle exec rake app:pwb:db:seed
# from spec/dummy folder or within an app using the engine:
# bundle exec rake pwb:db:seed
#
# Environment Variables:
# ----------------------
# SKIP_PROPERTIES=true  - Skip seeding sample properties (useful for production)
#
# Examples:
#   rake pwb:db:seed                        # Seeds with sample properties
#   SKIP_PROPERTIES=true rake pwb:db:seed   # Seeds without sample properties
#
namespace :pwb do
  namespace :db do
    desc 'Seeds the database with all seed data for the default website. Set SKIP_PROPERTIES=true to skip sample properties.'
    task seed: [:environment] do
      website = Pwb::Website.first || Pwb::Website.create!(subdomain: 'default', theme_name: 'default', default_currency: 'EUR', default_client_locale: 'en-UK')
      skip_properties = ENV['SKIP_PROPERTIES'].to_s.downcase == 'true'
      
      puts "🌱 Seeding data for website: #{website.slug || 'default'} (ID: #{website.id})"
      puts "   ⏭️  Skipping sample properties" if skip_properties
      
      Pwb::Seeder.seed!(website: website, skip_properties: skip_properties)
      Pwb::PagesSeeder.seed_page_parts!
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
      Pwb::PagesSeeder.seed_page_parts!
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
      
      # Seed page parts once (they are shared)
      Pwb::PagesSeeder.seed_page_parts!
      
      websites.each do |website|
        puts "\n📦 Processing website: #{website.subdomain || website.slug || 'default'} (ID: #{website.id})"
        # Set the current website context
        Pwb::Current.website = website
        Pwb::Seeder.seed!(website: website, skip_properties: skip_properties)
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
        company_display_name: name
      )
      
      puts "✅ Website created with ID: #{website.id}"
      puts "\n🌱 Seeding data for new tenant..."
      puts "   ⏭️  Skipping sample properties" if skip_properties
      
      Pwb::Current.website = website
      
      Pwb::Seeder.seed!(website: website, skip_properties: skip_properties)
      Pwb::PagesSeeder.seed_page_parts!
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
      Pwb::PagesSeeder.seed_page_parts!
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
  end
end
