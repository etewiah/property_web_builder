# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Load plans seeder
require_relative 'seeds/plans_seeds'

# Seed subscription plans (needed in all environments)
Pwb::PlansSeeder.seed!

# Load environment-specific seeds
case Rails.env
when 'e2e'
  load Rails.root.join('db', 'seeds', 'e2e_seeds.rb')
when 'development'
  # Load development seeds - you can create db/seeds/development_seeds.rb if needed
  # For now, use the same seeder as production
  Pwb::Seeder.seed!
  Pwb::PagesSeeder.seed_page_basics!
  Pwb::PagesSeeder.seed_page_parts!
when 'test'
  # Test environment typically uses fixtures, but you can seed here if needed
  puts "Test environment - skipping seeds (use fixtures instead)"
else
  # Production and other environments
  Pwb::Seeder.seed!
  Pwb::PagesSeeder.seed_page_basics!
  Pwb::PagesSeeder.seed_page_parts!
end
