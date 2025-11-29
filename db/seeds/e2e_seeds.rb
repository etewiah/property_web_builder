# E2E Test Data Seeds
# This file contains seed data specifically for Playwright end-to-end tests
# Run with: RAILS_ENV=e2e bin/rails db:seed

puts "🌱 Seeding E2E test data..."

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


# Create test users
puts "Creating test users..."

# Admin user for Tenant A
user_a_admin = Pwb::User.find_or_initialize_by(email: 'admin@tenant-a.test')
user_a_admin.assign_attributes(
  password: 'password123',
  password_confirmation: 'password123',
  website: tenant_a,
  admin: true
)
user_a_admin.save!

# Regular user for Tenant A
user_a_regular = Pwb::User.find_or_initialize_by(email: 'user@tenant-a.test')
user_a_regular.assign_attributes(
  password: 'password123',
  password_confirmation: 'password123',
  website: tenant_a,
  admin: false
)
user_a_regular.save!

# Admin user for Tenant B
user_b_admin = Pwb::User.find_or_initialize_by(email: 'admin@tenant-b.test')
user_b_admin.assign_attributes(
  password: 'password123',
  password_confirmation: 'password123',
  website: tenant_b,
  admin: true
)
user_b_admin.save!

# Regular user for Tenant B
user_b_regular = Pwb::User.find_or_initialize_by(email: 'user@tenant-b.test')
user_b_regular.assign_attributes(
  password: 'password123',
  password_confirmation: 'password123',
  website: tenant_b,
  admin: false
)
user_b_regular.save!

puts "✅ E2E test data seeded successfully!"
puts ""
puts "Test Credentials:"
puts "  Tenant A Admin:   admin@tenant-a.test / password123"
puts "  Tenant A User:    user@tenant-a.test / password123"
puts "  Tenant B Admin:   admin@tenant-b.test / password123"
puts "  Tenant B User:    user@tenant-b.test / password123"
puts ""
puts "Access URLs:"
puts "  Tenant A: http://tenant-a.localhost:3001"
puts "  Tenant B: http://tenant-b.localhost:3001"
