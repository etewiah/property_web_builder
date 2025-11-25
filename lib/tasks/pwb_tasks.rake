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
namespace :pwb do
  namespace :db do
    desc 'Seeds the database with all seed data.'
    task seed: [:environment] do
      Pwb::Seeder.seed!
      Pwb::PagesSeeder.seed_page_parts!
      Pwb::PagesSeeder.seed_page_basics!
      # below need to have page_parts populated to work correctly
      Pwb::ContentsSeeder.seed_page_content_translations!
      
      # Associate all pages with the website to ensure GraphQL queries work correctly
      website = Pwb::Website.first
      if website
        orphaned_pages = Pwb::Page.where(website_id: nil)
        if orphaned_pages.any?
          puts "🔧 Associating #{orphaned_pages.count} page(s) with website #{website.id}..."
          orphaned_pages.update_all(website_id: website.id)
          puts "✅ Pages successfully associated with website"
        end
      else
        puts "⚠️  Warning: No website found - pages not associated"
      end
    end

    desc 'Seeds the database with seed data for I18n, properties and field_keys'
    task seed_base: [:environment] do
      Pwb::Seeder.seed!
    end

    desc 'Seeds the database with PropertyWebBuilder default page content seed data. Will override existing content.'
    task seed_pages: [:environment] do
      p 'seed_page_parts!'
      Pwb::PagesSeeder.seed_page_parts!
      p 'seed_page_basics!'
      Pwb::PagesSeeder.seed_page_basics!
      # below need to have page_parts populated to work correctly
      p 'seed_page_content_translations!'
      Pwb::ContentsSeeder.seed_page_content_translations!
      
      # Associate all pages with the website to ensure GraphQL queries work correctly
      website = Pwb::Website.first
      if website
        orphaned_pages = Pwb::Page.where(website_id: nil)
        if orphaned_pages.any?
          puts "🔧 Associating #{orphaned_pages.count} page(s) with website #{website.id}..."
          orphaned_pages.update_all(website_id: website.id)
          puts "✅ Pages successfully associated with website"
        end
      else
        puts "⚠️  Warning: No website found - pages not associated"
      end
    end
  end
end
