# frozen_string_literal: true

namespace :playwright do
  desc "Reset and seed the E2E test database"
  task reset: :environment do
    unless Rails.env.e2e?
      puts "❌ This task can only be run in the e2e environment"
      puts "   Usage: RAILS_ENV=e2e bin/rails playwright:reset"
      exit 1
    end

    puts "🔄 Resetting E2E test database..."
    
    Rake::Task["db:drop"].invoke
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
    
    # Load the E2E seeds
    load Rails.root.join('db', 'seeds', 'e2e_seeds.rb')
    
    puts "✅ E2E database reset complete!"
  end

  desc "Start Rails server for E2E testing (port 3001)"
  task server: :environment do
    unless Rails.env.e2e?
      puts "❌ This task must be run in the e2e environment"
      puts "   Usage: RAILS_ENV=e2e bin/rails playwright:server"
      exit 1
    end

    puts "🚀 Starting Rails server for E2E testing on port 3001..."
    puts "   Tenant A: http://tenant-a.e2e.localhost:3001"
    puts "   Tenant B: http://tenant-b.e2e.localhost:3001"
    puts ""
    
    exec "bin/rails server -p 3001"
  end

  desc "Seed E2E test data without resetting database"
  task seed: :environment do
    unless Rails.env.e2e?
      puts "❌ This task can only be run in the e2e environment"
      puts "   Usage: RAILS_ENV=e2e bin/rails playwright:seed"
      exit 1
    end

    load Rails.root.join('db', 'seeds', 'e2e_seeds.rb')
  end
end
