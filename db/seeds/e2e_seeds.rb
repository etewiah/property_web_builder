
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

  # Seed pages and page parts with website association for multi-tenant isolation
  Pwb::PagesSeeder.seed_page_basics!(website: website)
  Pwb::PagesSeeder.seed_page_parts!(website: website)
  Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
end

# Create test websites/tenants with bristol theme
puts "Creating test tenants..."
tenant_a = Pwb::Website.find_or_create_by!(subdomain: 'tenant-a') do |w|
  w.slug = 'tenant-a'
  w.company_display_name = 'Tenant A Real Estate'
  w.default_client_locale = 'en-UK'
  w.theme_name = 'bristol'
end
# Ensure theme is set even if record already exists
tenant_a.update!(theme_name: 'bristol') if tenant_a.theme_name != 'bristol'

tenant_b = Pwb::Website.find_or_create_by!(subdomain: 'tenant-b') do |w|
  w.slug = 'tenant-b'
  w.company_display_name = 'Tenant B Real Estate'
  w.default_client_locale = 'en-UK'
  w.theme_name = 'bristol'
end
# Ensure theme is set even if record already exists
tenant_b.update!(theme_name: 'bristol') if tenant_b.theme_name != 'bristol'

# Seed each tenant with full data
seed_for_website(tenant_a)
seed_for_website(tenant_b)

# Create test users
puts "Creating test users..."

e2e_users = YAML.load_file(Rails.root.join('db', 'yml_seeds', 'e2e_users.yml'))

# Admin user for Tenant A
user_data = e2e_users['tenant_a']['admin']
user_a_admin = Pwb::User.find_or_initialize_by(email: user_data['email'])
user_a_admin.assign_attributes(
  password: user_data['password'],
  password_confirmation: user_data['password'],
  website_id: tenant_a.id,
  admin: user_data['admin']
)
user_a_admin.save!

# Regular user for Tenant A
user_data = e2e_users['tenant_a']['regular']
user_a_regular = Pwb::User.find_or_initialize_by(email: user_data['email'])
user_a_regular.assign_attributes(
  password: user_data['password'],
  password_confirmation: user_data['password'],
  website_id: tenant_a.id,
  admin: user_data['admin']
)
user_a_regular.save!

# Admin user for Tenant B
user_data = e2e_users['tenant_b']['admin']
user_b_admin = Pwb::User.find_or_initialize_by(email: user_data['email'])
user_b_admin.assign_attributes(
  password: user_data['password'],
  password_confirmation: user_data['password'],
  website_id: tenant_b.id,
  admin: user_data['admin']
)
user_b_admin.save!

# Regular user for Tenant B
user_data = e2e_users['tenant_b']['regular']
user_b_regular = Pwb::User.find_or_initialize_by(email: user_data['email'])
user_b_regular.assign_attributes(
  password: user_data['password'],
  password_confirmation: user_data['password'],
  website_id: tenant_b.id,
  admin: user_data['admin']
)
user_b_regular.save!

# Create user memberships for admin access
puts "Creating user memberships..."
# Admin membership for Tenant A admin
Pwb::UserMembership.find_or_create_by!(user: user_a_admin, website: tenant_a) do |m|
  m.role = 'admin'
  m.active = true
end

# Regular membership for Tenant A regular user
Pwb::UserMembership.find_or_create_by!(user: user_a_regular, website: tenant_a) do |m|
  m.role = 'member'
  m.active = true
end

# Admin membership for Tenant B admin
Pwb::UserMembership.find_or_create_by!(user: user_b_admin, website: tenant_b) do |m|
  m.role = 'admin'
  m.active = true
end

# Regular membership for Tenant B regular user
Pwb::UserMembership.find_or_create_by!(user: user_b_regular, website: tenant_b) do |m|
  m.role = 'member'
  m.active = true
end

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

# Create sample messages for E2E tests
puts "Creating sample messages..."
contact_a = Pwb::Contact.find_by(primary_email: 'contact@tenant-a.test')
contact_b = Pwb::Contact.find_by(primary_email: 'contact@tenant-b.test')

# Messages for Tenant A
[
  {
    title: 'Property Inquiry - Villa',
    content: 'Hi, I am interested in the villa listing. Could you please provide more details about the property and arrange a viewing?',
    origin_email: 'john.doe@example.com',
    delivery_email: 'admin@tenant-a.test',
    delivery_success: true,
    locale: 'en',
    host: 'tenant-a.e2e.localhost'
  },
  {
    title: 'General Contact',
    content: 'Hello, I would like to know more about your real estate services. Do you handle commercial properties as well?',
    origin_email: 'jane.smith@example.com',
    delivery_email: 'admin@tenant-a.test',
    delivery_success: true,
    locale: 'en',
    host: 'tenant-a.e2e.localhost'
  },
  {
    title: 'Urgent: Looking for apartment',
    content: 'We are relocating next month and urgently need a 2-bedroom apartment. Please contact me ASAP.',
    origin_email: 'urgent.buyer@example.com',
    delivery_email: 'admin@tenant-a.test',
    delivery_success: false,
    locale: 'en',
    host: 'tenant-a.e2e.localhost'
  }
].each do |msg_attrs|
  Pwb::Message.find_or_create_by!(
    website_id: tenant_a.id,
    origin_email: msg_attrs[:origin_email],
    title: msg_attrs[:title]
  ) do |m|
    m.content = msg_attrs[:content]
    m.delivery_email = msg_attrs[:delivery_email]
    m.delivery_success = msg_attrs[:delivery_success]
    m.locale = msg_attrs[:locale]
    m.host = msg_attrs[:host]
    m.contact = contact_a
  end
end

# Messages for Tenant B
[
  {
    title: 'Investment Property Inquiry',
    content: 'I am looking for investment properties in the area. What is your current inventory for buy-to-let opportunities?',
    origin_email: 'investor@example.com',
    delivery_email: 'admin@tenant-b.test',
    delivery_success: true,
    locale: 'en',
    host: 'tenant-b.e2e.localhost'
  },
  {
    title: 'Rental Inquiry',
    content: 'Do you have any long-term rental properties available? Budget is around 1500 EUR per month.',
    origin_email: 'renter@example.com',
    delivery_email: 'admin@tenant-b.test',
    delivery_success: true,
    locale: 'en',
    host: 'tenant-b.e2e.localhost'
  }
].each do |msg_attrs|
  Pwb::Message.find_or_create_by!(
    website_id: tenant_b.id,
    origin_email: msg_attrs[:origin_email],
    title: msg_attrs[:title]
  ) do |m|
    m.content = msg_attrs[:content]
    m.delivery_email = msg_attrs[:delivery_email]
    m.delivery_success = msg_attrs[:delivery_success]
    m.locale = msg_attrs[:locale]
    m.host = msg_attrs[:host]
    m.contact = contact_b
  end
end

# Create sample properties with sale and rental listings
# Note: Pwb::ListedProperty is a read-only materialized view. Create properties
# using Pwb::RealtyAsset with associated listings.
puts "Creating sample properties with listings..."

# Path to seed images (downloaded from Unsplash - royalty-free)
SEED_IMAGES_PATH = Rails.root.join('db', 'seeds', 'images')

# Helper to attach an image to a property
def attach_property_image(asset, image_filename)
  image_path = SEED_IMAGES_PATH.join(image_filename)
  unless File.exist?(image_path)
    puts "    WARNING: Image not found: #{image_path}"
    return
  end

  # Check if image already attached
  if asset.prop_photos.any?
    puts "    Image already attached to #{asset.reference}"
    return
  end

  photo = Pwb::PropPhoto.create!(realty_asset: asset, sort_order: 1)
  photo.image.attach(
    io: File.open(image_path),
    filename: image_filename,
    content_type: 'image/jpeg'
  )
  photo.save!
  puts "    Attached #{image_filename} to #{asset.reference}"
end

# Helper to add features to a property
def add_property_features(asset, feature_keys)
  added = 0
  feature_keys.each do |key|
    feature = asset.features.find_or_create_by!(feature_key: key)
    added += 1 if feature.previously_new_record?
  end
  puts "    Added #{added} features to #{asset.reference}" if added > 0
end

# Helper to create a property with sale and/or rental listings
# Uses website_id instead of website object to avoid class reloading issues in Rake tasks
def create_property(website:, attrs:, sale_listing: nil, rental_listing: nil, image: nil, features: [])
  website_id = website.id

  # Check if property already exists
  existing = Pwb::RealtyAsset.find_by(website_id: website_id, reference: attrs[:reference])
  if existing
    # Update features and image even for existing properties
    add_property_features(existing, features) if features.any?
    attach_property_image(existing, image) if image
    return existing
  end

  asset = Pwb::RealtyAsset.create!(
    website_id: website_id,
    reference: attrs[:reference],
    prop_type_key: attrs[:prop_type],
    prop_state_key: attrs[:prop_state],
    street_address: attrs[:address],
    city: attrs[:city],
    region: attrs[:region],
    country: attrs[:country],
    postal_code: attrs[:postal_code],
    count_bedrooms: attrs[:bedrooms],
    count_bathrooms: attrs[:bathrooms],
    count_garages: attrs[:garages],
    constructed_area: attrs[:constructed_area],
    plot_area: attrs[:plot_area],
    year_construction: attrs[:year_built],
    latitude: attrs[:latitude],
    longitude: attrs[:longitude]
  )

  # Add features/amenities
  add_property_features(asset, features) if features.any?

  # Attach image
  attach_property_image(asset, image) if image

  if sale_listing
    listing = Pwb::SaleListing.create!(
      realty_asset: asset,
      visible: true,
      active: true,
      highlighted: sale_listing[:highlighted] || false,
      price_sale_current_cents: sale_listing[:price_cents],
      price_sale_current_currency: 'USD'
    )
    listing.title_en = sale_listing[:title]
    listing.description_en = sale_listing[:description]
    listing.save!
  end

  if rental_listing
    listing = Pwb::RentalListing.create!(
      realty_asset: asset,
      visible: true,
      active: true,
      highlighted: rental_listing[:highlighted] || false,
      for_rent_long_term: rental_listing[:long_term] || true,
      for_rent_short_term: rental_listing[:short_term] || false,
      furnished: rental_listing[:furnished] || false,
      price_rental_monthly_current_cents: rental_listing[:monthly_price_cents],
      price_rental_monthly_current_currency: 'USD'
    )
    listing.title_en = rental_listing[:title]
    listing.description_en = rental_listing[:description]
    listing.save!
  end

  asset
end

# Sample US properties for sale (4 properties)
sale_properties = [
  {
    attrs: {
      reference: 'US-SALE-001',
      prop_type: 'types.detached_house',
      prop_state: 'states.excellent',
      address: '742 Evergreen Terrace',
      city: 'Springfield',
      region: 'Illinois',
      country: 'USA',
      postal_code: '62701',
      bedrooms: 4,
      bathrooms: 3,
      garages: 2,
      constructed_area: 2400,
      plot_area: 8500,
      year_built: 2018,
      latitude: 39.7817,
      longitude: -89.6501
    },
    sale_listing: {
      title: 'Modern Family Home in Springfield',
      description: 'Beautiful 4-bedroom family home in a quiet neighborhood. Features include a spacious backyard, updated kitchen with granite countertops, hardwood floors throughout, and a two-car garage. Close to schools and parks.',
      price_cents: 425000_00,
      highlighted: true
    },
    image: 'house_family.jpg',
    features: [
      'features.private_garden',
      'features.terrace',
      'features.patio',
      'amenities.central_heating',
      'amenities.air_conditioning',
      'amenities.alarm_system'
    ]
  },
  {
    attrs: {
      reference: 'US-SALE-002',
      prop_type: 'types.apartment',
      prop_state: 'states.new_build',
      address: '200 Park Avenue',
      city: 'New York',
      region: 'New York',
      country: 'USA',
      postal_code: '10166',
      bedrooms: 2,
      bathrooms: 2,
      garages: 1,
      constructed_area: 1200,
      plot_area: nil,
      year_built: 2024,
      latitude: 40.7549,
      longitude: -73.9763
    },
    sale_listing: {
      title: 'Luxury Manhattan Apartment',
      description: 'Stunning new construction apartment in Midtown Manhattan. Floor-to-ceiling windows offer breathtaking city views. Building amenities include 24-hour doorman, fitness center, and rooftop terrace.',
      price_cents: 1850000_00,
      highlighted: true
    },
    image: 'apartment_luxury.jpg',
    features: [
      'features.balcony',
      'amenities.air_conditioning',
      'amenities.central_heating',
      'amenities.video_entry',
      'amenities.security'
    ]
  },
  {
    attrs: {
      reference: 'US-SALE-003',
      prop_type: 'types.villa',
      prop_state: 'states.excellent',
      address: '1500 Ocean Drive',
      city: 'Miami Beach',
      region: 'Florida',
      country: 'USA',
      postal_code: '33139',
      bedrooms: 5,
      bathrooms: 4,
      garages: 3,
      constructed_area: 4500,
      plot_area: 12000,
      year_built: 2020,
      latitude: 25.7825,
      longitude: -80.1324
    },
    sale_listing: {
      title: 'Oceanfront Villa in Miami Beach',
      description: 'Exquisite oceanfront villa with private beach access. Features include infinity pool, smart home technology, chef\'s kitchen, wine cellar, and a private dock. Perfect for luxury coastal living.',
      price_cents: 5500000_00,
      highlighted: false
    },
    image: 'villa_ocean.jpg',
    features: [
      'features.private_pool',
      'features.heated_pool',
      'features.private_garden',
      'features.terrace',
      'features.solarium',
      'amenities.air_conditioning',
      'amenities.alarm_system',
      'amenities.solar_energy',
      'amenities.security'
    ]
  },
  {
    attrs: {
      reference: 'US-SALE-004',
      prop_type: 'types.townhouse',
      prop_state: 'states.renovated',
      address: '456 Capitol Hill',
      city: 'Washington',
      region: 'District of Columbia',
      country: 'USA',
      postal_code: '20003',
      bedrooms: 3,
      bathrooms: 2,
      garages: 1,
      constructed_area: 1800,
      plot_area: 2000,
      year_built: 1920,
      latitude: 38.8899,
      longitude: -76.9996
    },
    sale_listing: {
      title: 'Historic Capitol Hill Townhouse',
      description: 'Beautifully renovated historic townhouse on Capitol Hill. Original hardwood floors and exposed brick blend with modern amenities. Private patio garden and roof deck with city views.',
      price_cents: 875000_00,
      highlighted: false
    },
    image: 'townhouse_historic.jpg',
    features: [
      'features.patio',
      'features.terrace',
      'amenities.gas_heating',
      'amenities.air_conditioning',
      'amenities.alarm_system'
    ]
  }
]

# Sample US properties for rent (4 properties)
rental_properties = [
  {
    attrs: {
      reference: 'US-RENT-001',
      prop_type: 'types.apartment',
      prop_state: 'states.excellent',
      address: '1000 Wilshire Blvd',
      city: 'Los Angeles',
      region: 'California',
      country: 'USA',
      postal_code: '90017',
      bedrooms: 1,
      bathrooms: 1,
      garages: 1,
      constructed_area: 750,
      plot_area: nil,
      year_built: 2019,
      latitude: 34.0522,
      longitude: -118.2673
    },
    rental_listing: {
      title: 'Modern Downtown LA Apartment',
      description: 'Stylish 1-bedroom apartment in the heart of downtown LA. Walking distance to restaurants, shopping, and metro. In-unit washer/dryer, stainless steel appliances, and city views.',
      monthly_price_cents: 2800_00,
      long_term: true,
      short_term: false,
      furnished: false,
      highlighted: true
    },
    image: 'apartment_downtown.jpg',
    features: [
      'features.balcony',
      'amenities.air_conditioning',
      'amenities.central_heating',
      'amenities.video_entry'
    ]
  },
  {
    attrs: {
      reference: 'US-RENT-002',
      prop_type: 'types.detached_house',
      prop_state: 'states.good',
      address: '789 Suburban Lane',
      city: 'Austin',
      region: 'Texas',
      country: 'USA',
      postal_code: '78701',
      bedrooms: 3,
      bathrooms: 2,
      garages: 2,
      constructed_area: 1600,
      plot_area: 6000,
      year_built: 2015,
      latitude: 30.2672,
      longitude: -97.7431
    },
    rental_listing: {
      title: 'Family Home in Austin',
      description: 'Spacious 3-bedroom home in a family-friendly neighborhood. Large fenced backyard, open floor plan, and two-car garage. Near top-rated schools and parks.',
      monthly_price_cents: 3200_00,
      long_term: true,
      short_term: false,
      furnished: false,
      highlighted: true
    },
    image: 'house_suburban.jpg',
    features: [
      'features.private_garden',
      'features.patio',
      'amenities.air_conditioning',
      'amenities.central_heating',
      'amenities.alarm_system'
    ]
  },
  {
    attrs: {
      reference: 'US-RENT-003',
      prop_type: 'types.studio',
      prop_state: 'states.new_build',
      address: '500 Pike Street',
      city: 'Seattle',
      region: 'Washington',
      country: 'USA',
      postal_code: '98101',
      bedrooms: 0,
      bathrooms: 1,
      garages: 0,
      constructed_area: 450,
      plot_area: nil,
      year_built: 2023,
      latitude: 47.6062,
      longitude: -122.3321
    },
    rental_listing: {
      title: 'Cozy Studio in Downtown Seattle',
      description: 'Brand new studio apartment perfect for young professionals. Murphy bed, full kitchen, and stunning views of Puget Sound. Building has gym and co-working space.',
      monthly_price_cents: 1950_00,
      long_term: true,
      short_term: true,
      furnished: true,
      highlighted: false
    },
    image: 'studio_modern.jpg',
    features: [
      'amenities.air_conditioning',
      'amenities.electric_heating',
      'amenities.video_entry',
      'amenities.security'
    ]
  },
  {
    attrs: {
      reference: 'US-RENT-004',
      prop_type: 'types.penthouse',
      prop_state: 'states.excellent',
      address: '100 Lakefront Drive',
      city: 'Chicago',
      region: 'Illinois',
      country: 'USA',
      postal_code: '60601',
      bedrooms: 3,
      bathrooms: 3,
      garages: 2,
      constructed_area: 2800,
      plot_area: nil,
      year_built: 2021,
      latitude: 41.8781,
      longitude: -87.6298
    },
    rental_listing: {
      title: 'Luxury Penthouse on Lake Michigan',
      description: 'Spectacular penthouse with panoramic lake views. Private elevator entrance, chef\'s kitchen, spa bathroom, and wraparound terrace. Full-service building with concierge.',
      monthly_price_cents: 8500_00,
      long_term: true,
      short_term: false,
      furnished: true,
      highlighted: false
    },
    image: 'penthouse_luxury.jpg',
    features: [
      'features.terrace',
      'features.balcony',
      'amenities.air_conditioning',
      'amenities.central_heating',
      'amenities.video_entry',
      'amenities.security',
      'amenities.alarm_system'
    ]
  }
]

# Create sale properties for Tenant A
puts "  Creating sale listings for Tenant A..."
sale_properties.each do |prop|
  create_property(
    website: tenant_a,
    attrs: prop[:attrs],
    sale_listing: prop[:sale_listing],
    image: prop[:image],
    features: prop[:features] || []
  )
end

# Create rental properties for Tenant A
puts "  Creating rental listings for Tenant A..."
rental_properties.each do |prop|
  create_property(
    website: tenant_a,
    attrs: prop[:attrs],
    rental_listing: prop[:rental_listing],
    image: prop[:image],
    features: prop[:features] || []
  )
end

# Create a subset for Tenant B (2 sale, 2 rental)
puts "  Creating listings for Tenant B..."
sale_properties.take(2).each do |prop|
  attrs = prop[:attrs].dup
  attrs[:reference] = attrs[:reference].sub('US-SALE', 'B-SALE')
  create_property(
    website: tenant_b,
    attrs: attrs,
    sale_listing: prop[:sale_listing],
    image: prop[:image],
    features: prop[:features] || []
  )
end

rental_properties.take(2).each do |prop|
  attrs = prop[:attrs].dup
  attrs[:reference] = attrs[:reference].sub('US-RENT', 'B-RENT')
  create_property(
    website: tenant_b,
    attrs: attrs,
    rental_listing: prop[:rental_listing],
    image: prop[:image],
    features: prop[:features] || []
  )
end

# Refresh the materialized view to include the new properties
puts "Refreshing properties materialized view..."
Pwb::ListedProperty.refresh rescue nil

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
