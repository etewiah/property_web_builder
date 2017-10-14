# desc "Explaining what the task does"
# task :pwb do
#   # Task goes here
# end
require 'pwb/seeder'
require 'pwb/pages_seeder'
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
      Pwb::PagesSeeder.seed_page_content_translations!
    end

    desc 'Seeds the database with seed data for I18n, properties and field_keys'
    task seed_base: [:environment] do
      Pwb::Seeder.seed!
    end

    desc 'Seeds the database with PropertyWebBuilder default page content seed data. Will override existing content.'
    task seed_pages: [:environment] do
      Pwb::PagesSeeder.seed_page_parts!
      Pwb::PagesSeeder.seed_page_basics!
      Pwb::PagesSeeder.seed_page_content_translations!
    end
  end
end
