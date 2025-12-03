
# E2E Test Data Seeds
# This file contains seed data specifically for Playwright end-to-end tests
# Run with: RAILS_ENV=e2e bin/rails db:seed

puts "🌱 Seeding E2E test data..."

# Helper to seed using main YAML files
def seed_for_website(website)
  # Load translations (if needed for tests)
  %w[
    translations_ca.rb translations_en.rb translations_es.rb translations_de.rb
    translations_fr.rb translations_it.rb translations_nl.rb translations_pl.rb
    translations_pt.rb translations_ro.rb translations_ru.rb translations_ko.rb translations_bg.rb
  ].each do |file|
    load File.join(Rails.root, "db", "seeds", file) if File.exist?(File.join(Rails.root, "db", "seeds", file))
  end

  # Seed agency, website, properties, field keys, users, contacts, links
  Pwb::Seeder.seed!(website: website)
  
  # Seed pages and content using dedicated seeders
  Pwb::PagesSeeder.seed_page_basics!(website: website)
  Pwb::PagesSeeder.seed_page_parts!
  Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
end

# Create test websites/tenants
puts "Creating test tenants..."
tenant_a = Pwb::Website.find_or_create_by!(subdomain: 'tenant-a') do |w|
  w.slug = 'tenant-a'
  w.company_display_name = 'Tenant A Real Estate'
  w.default_client_locale = 'en-UK'
end

tenant_b = Pwb::Website.find_or_create_by!(subdomain: 'tenant-b') do |w|
  w.slug = 'tenant-b'
  w.company_display_name = 'Tenant B Real Estate'
  w.default_client_locale = 'en-UK'
end

# Seed each tenant with full data
seed_for_website(tenant_a)
seed_for_website(tenant_b)

# Create test users
puts "Creating test users..."

# Admin user for Tenant A
user_a_admin = Pwb::User.find_or_initialize_by(email: 'admin@tenant-a.test')
user_a_admin.assign_attributes(
  password: 'password123',
  password_confirmation: 'password123',
  website_id: tenant_a.id,
  admin: true
)
user_a_admin.save!

# Regular user for Tenant A
user_a_regular = Pwb::User.find_or_initialize_by(email: 'user@tenant-a.test')
user_a_regular.assign_attributes(
  password: 'password123',
  password_confirmation: 'password123',
  website_id: tenant_a.id,
  admin: false
)
user_a_regular.save!

# Admin user for Tenant B
user_b_admin = Pwb::User.find_or_initialize_by(email: 'admin@tenant-b.test')
user_b_admin.assign_attributes(
  password: 'password123',
  password_confirmation: 'password123',
  website_id: tenant_b.id,
  admin: true
)
user_b_admin.save!

# Regular user for Tenant B
user_b_regular = Pwb::User.find_or_initialize_by(email: 'user@tenant-b.test')
user_b_regular.assign_attributes(
  password: 'password123',
  password_confirmation: 'password123',
  website_id: tenant_b.id,
  admin: false
)
user_b_regular.save!

# Extra useful test data for E2E
puts "Creating extra test contacts..."
Pwb::Contact.find_or_create_by!(primary_email: 'contact@tenant-a.test') do |c|
  c.first_name = 'ContactA'
  c.last_name = 'TestA'
  c.website_id = tenant_a.id
end
Pwb::Contact.find_or_create_by!(primary_email: 'contact@tenant-b.test') do |c|
  c.first_name = 'ContactB'
  c.last_name = 'TestB'
  c.website_id = tenant_b.id
end

# Add a sample property for each tenant if not present
puts "Ensuring at least one property per tenant..."
if tenant_a.props.count == 0
  Pwb::Property.create!(
    title: 'E2E Villa Tenant A',
    description: 'Sample property for E2E tests (Tenant A)',
    website: tenant_a,
    price: 500000,
    prop_type: 'villa',
    operation_type: 'sale',
    address: '123 E2E St, CityA',
    owner_email: 'owner@tenant-a.test'
  )
end
if tenant_b.props.count == 0
  Pwb::Property.create!(
    title: 'E2E Villa Tenant B',
    description: 'Sample property for E2E tests (Tenant B)',
    website: tenant_b,
    price: 600000,
    prop_type: 'villa',
    operation_type: 'sale',
    address: '456 E2E Ave, CityB',
    owner_email: 'owner@tenant-b.test'
  )
end

puts "✅ E2E test data seeded successfully!"
puts ""
puts "Test Credentials:"
puts "  Tenant A Admin:   admin@tenant-a.test / password123"
puts "  Tenant A User:    user@tenant-a.test / password123"
puts "  Tenant B Admin:   admin@tenant-b.test / password123"
puts "  Tenant B User:    user@tenant-b.test / password123"
puts ""
puts "Access URLs:"
puts "  Tenant A: http://tenant-a.e2e.localhost:3001"
puts "  Tenant B: http://tenant-b.e2e.localhost:3001"
