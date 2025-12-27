# frozen_string_literal: true

# Rake task for seeding initial website data with onboarding enabled.
#
# This creates a minimal website setup where the first admin who logs in
# will be guided through the site admin onboarding wizard (5 steps).
#
# The onboarding wizard collects:
#   Step 1: Welcome - Get started
#   Step 2: Profile - Agency name, contact info
#   Step 3: Property - Add first property (can skip)
#   Step 4: Theme - Choose website theme
#   Step 5: Complete - Finish setup
#
# Environment Variables:
# ----------------------
# ADMIN_EMAIL     - Admin email (default: admin@example.com)
# ADMIN_PASSWORD  - Admin password (default: password123)
# SUBDOMAIN       - Website subdomain (default: onboarding)
# THEME           - Initial theme (default: default)
# SEED_PACK       - Optional seed pack to apply (e.g., 'barcelona', 'brisbane')
# SKIP_PROPERTIES - Skip seeding sample properties if using seed pack (default: true)
#
# Examples:
# ---------
#   # Basic setup - admin will go through full onboarding
#   rake pwb:seed_for_onboarding
#
#   # Custom admin credentials
#   ADMIN_EMAIL=john@agency.com ADMIN_PASSWORD=secure123 rake pwb:seed_for_onboarding
#
#   # With a seed pack (pre-seeds content, admin still does onboarding)
#   SEED_PACK=barcelona rake pwb:seed_for_onboarding
#
#   # Custom subdomain
#   SUBDOMAIN=my-agency rake pwb:seed_for_onboarding
#
namespace :pwb do
  desc 'Seeds a minimal website with onboarding enabled. First admin login triggers the setup wizard.'
  task seed_for_onboarding: :environment do
    puts "\n" + "=" * 60
    puts "🚀 SEED FOR ONBOARDING"
    puts "=" * 60

    # Parse environment variables
    admin_email = ENV.fetch('ADMIN_EMAIL', 'admin@example.com')
    admin_password = ENV.fetch('ADMIN_PASSWORD', 'password123')
    subdomain = ENV.fetch('SUBDOMAIN', 'onboarding')
    theme_name = ENV.fetch('THEME', 'default')
    seed_pack_name = ENV['SEED_PACK']
    skip_properties = ENV.fetch('SKIP_PROPERTIES', 'true').downcase == 'true'

    puts "\nConfiguration:"
    puts "  Admin Email:    #{admin_email}"
    puts "  Admin Password: #{'*' * admin_password.length}"
    puts "  Subdomain:      #{subdomain}"
    puts "  Theme:          #{theme_name}"
    puts "  Seed Pack:      #{seed_pack_name || 'none'}"
    puts "  Skip Props:     #{skip_properties}"
    puts ""

    # Step 1: Find or create website
    puts "📦 Setting up website..."
    website = find_or_create_website_for_onboarding(subdomain, theme_name)
    puts "   ✓ Website: #{website.subdomain} (ID: #{website.id})"
    puts "   ✓ State: #{website.provisioning_state}"

    # Set current website context
    Pwb::Current.website = website
    ActsAsTenant.current_tenant = website

    # Step 2: Create minimal agency (required for website to function)
    puts "\n🏢 Setting up agency..."
    agency = find_or_create_minimal_agency(website)
    puts "   ✓ Agency: #{agency.company_name || 'Unnamed'} (ID: #{agency.id})"

    # Step 3: Create admin user with onboarding NOT completed
    puts "\n👤 Setting up admin user..."
    user = find_or_create_admin_for_onboarding(website, admin_email, admin_password)
    puts "   ✓ User: #{user.email} (ID: #{user.id})"
    puts "   ✓ Onboarding state: #{user.onboarding_state}"
    puts "   ✓ Site admin onboarding: #{user.site_admin_onboarding_completed_at ? 'completed' : 'pending'}"

    # Step 4: Create owner membership
    puts "\n🔗 Setting up membership..."
    membership = find_or_create_owner_membership(user, website)
    puts "   ✓ Role: #{membership.role}"
    puts "   ✓ Active: #{membership.active}"

    # Step 5: Apply seed pack if specified
    if seed_pack_name.present?
      puts "\n🌱 Applying seed pack: #{seed_pack_name}..."
      apply_seed_pack_for_onboarding(website, seed_pack_name, skip_properties)
    else
      # Seed minimal content (navigation, essential pages)
      puts "\n🌱 Seeding minimal content..."
      seed_minimal_content(website)
    end

    # Summary
    puts "\n" + "=" * 60
    puts "✅ SETUP COMPLETE"
    puts "=" * 60
    puts "\nThe website is ready. When the admin logs in, they will be"
    puts "guided through the site setup wizard."
    puts "\nAccess the site at:"
    puts "  Development: http://#{subdomain}.lvh.me:3000"
    puts "  Production:  https://#{subdomain}.propertywebbuilder.com"
    puts "\nLogin credentials:"
    puts "  Email:    #{admin_email}"
    puts "  Password: #{admin_password}"
    puts "\nThe onboarding wizard will:"
    puts "  1. Welcome the admin"
    puts "  2. Collect agency profile info"
    puts "  3. Help add the first property (optional)"
    puts "  4. Let them choose a theme"
    puts "  5. Mark setup as complete"
    puts ""
  end

  desc 'Reset onboarding state for an existing admin user. Usage: rake pwb:reset_onboarding[email]'
  task :reset_onboarding, [:email] => :environment do |_t, args|
    email = args[:email]

    if email.blank?
      puts "Usage: rake pwb:reset_onboarding[admin@example.com]"
      puts "       This resets the user's site_admin_onboarding_completed_at to nil"
      exit 1
    end

    user = Pwb::User.find_by(email: email)
    if user.nil?
      puts "❌ User not found: #{email}"
      exit 1
    end

    if user.site_admin_onboarding_completed_at.nil?
      puts "ℹ️  User #{email} already has onboarding pending"
    else
      user.update!(site_admin_onboarding_completed_at: nil)
      puts "✅ Reset onboarding for #{email}"
      puts "   Next login will trigger the setup wizard"
    end
  end
end

# Helper methods

def find_or_create_website_for_onboarding(subdomain, theme_name)
  website = Pwb::Website.find_by(subdomain: subdomain)

  if website
    # Update existing website to ensure it's live
    unless website.live?
      website.update!(provisioning_state: 'live')
    end
    website
  else
    # Create new website with live state
    Pwb::Website.create!(
      subdomain: subdomain,
      theme_name: theme_name,
      provisioning_state: 'live',
      default_currency: 'EUR',
      default_client_locale: 'en'
    )
  end
end

def find_or_create_minimal_agency(website)
  agency = Pwb::Agency.find_by(website: website)

  if agency
    agency
  else
    Pwb::Agency.create!(
      website: website,
      company_name: nil # Will be set during onboarding
    )
  end
end

def find_or_create_admin_for_onboarding(website, email, password)
  user = Pwb::User.find_by(email: email)

  if user
    # Reset onboarding state for existing user
    user.update!(
      site_admin_onboarding_completed_at: nil,
      website: website,
      admin: true
    )
    # Set password only if explicitly provided via ENV
    if ENV['ADMIN_PASSWORD'].present?
      user.update!(password: password, password_confirmation: password)
    end
    user
  else
    # Create new user with onboarding NOT completed
    Pwb::User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      website: website,
      admin: true,
      onboarding_state: 'active', # User account is active
      site_admin_onboarding_completed_at: nil # But site setup wizard pending
    )
  end
end

def find_or_create_owner_membership(user, website)
  membership = Pwb::UserMembership.find_by(user: user, website: website)

  if membership
    # Ensure they're an owner and active
    membership.update!(role: 'owner', active: true) unless membership.owner? && membership.active?
    membership
  else
    Pwb::UserMembership.create!(
      user: user,
      website: website,
      role: 'owner',
      active: true
    )
  end
end

def apply_seed_pack_for_onboarding(website, pack_name, skip_properties)
  require_relative '../pwb/seed_pack'

  pack = Pwb::SeedPack.find(pack_name)
  if pack.nil?
    puts "   ⚠️  Seed pack '#{pack_name}' not found, skipping"
    puts "   Available packs: #{Pwb::SeedPack.available.map(&:name).join(', ')}"
    return
  end

  options = {}
  options[:skip_properties] = true if skip_properties
  options[:skip_users] = true # Don't override our admin user
  options[:skip_agency] = true # Agency will be configured during onboarding

  begin
    pack.apply!(website: website, options: options)
    puts "   ✓ Seed pack applied"
  rescue StandardError => e
    puts "   ⚠️  Seed pack error: #{e.message}"
    puts "   Continuing with minimal setup..."
  end
end

def seed_minimal_content(website)
  # Seed field keys (property types, features, amenities, etc.)
  begin
    seed_field_keys_for_website(website)
    puts "   ✓ Field keys seeded"
  rescue StandardError => e
    puts "   ⚠️  Field keys seeding error: #{e.message}"
  end

  # Seed essential pages and navigation
  begin
    Pwb::PagesSeeder.seed_page_parts!(website: website)
    Pwb::PagesSeeder.seed_page_basics!(website: website)
    puts "   ✓ Essential pages seeded"
  rescue StandardError => e
    puts "   ⚠️  Pages seeding error: #{e.message}"
  end

  # Seed content translations
  begin
    Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
    puts "   ✓ Content translations seeded"
  rescue StandardError => e
    puts "   ⚠️  Content seeding error: #{e.message}"
  end
end

def seed_field_keys_for_website(website)
  # Load field keys from the default seed file
  yml_path = Rails.root.join('db', 'yml_seeds', 'field_keys.yml')
  return unless File.exist?(yml_path)

  field_keys_yml = YAML.load_file(yml_path)
  return if field_keys_yml.blank?

  field_keys_yml.each do |field_key_data|
    global_key = field_key_data["global_key"]

    # Check if field_key already exists for this website
    existing = website.field_keys.find_by(global_key: global_key)
    next if existing.present?

    # Extract translations before creating
    translations = field_key_data.delete("translations")

    # Create field_key with website association
    field_key = website.field_keys.create!(field_key_data)

    # Set translations using Mobility
    next unless translations.present?

    translations.each do |locale, label|
      next if label.blank?

      Mobility.with_locale(locale.to_sym) do
        field_key.label = label
      end
    end
    field_key.save!
  end
end
