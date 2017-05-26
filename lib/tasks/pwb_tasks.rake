# desc "Explaining what the task does"
# task :pwb do
#   # Task goes here
# end
require 'pwb/seeder'
require 'pwb/cms_data_loader'
# from root of engine:
# bundle exec rake app:pwb:db:seed     
# from spec/dummy folder or within an app using the engine:
# bundle exec rake pwb:db:seed
namespace :pwb do
  namespace :db do
    desc 'Seeds the database with Pwb defaults'
    task seed: [:environment] do
      Pwb::Seeder.seed!
    end
  end
end
