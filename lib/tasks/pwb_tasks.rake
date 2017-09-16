# desc "Explaining what the task does"
# task :pwb do
#   # Task goes here
# end
require 'pwb/seeder'
require 'pwb/content_translations_seeder'
# from root of engine:
# bundle exec rake app:pwb:db:seed     
# from spec/dummy folder or within an app using the engine:
# bundle exec rake pwb:db:seed
namespace :pwb do
  namespace :db do
    desc 'Seeds the database with PropertyWebBuilder default seed data'
    task seed: [:environment] do
      Pwb::Seeder.seed!
    end
    desc 'Seeds the database with PropertyWebBuilder default page content seed data. Will override existing content.'
    task seed_pages: [:environment] do
      Pwb::ContentTranslationsSeeder.seed_content_translations!
    end
  end
end
