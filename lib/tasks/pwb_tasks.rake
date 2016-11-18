# desc "Explaining what the task does"
# task :pwb do
#   # Task goes here
# end
require 'pwb/seeder'
# rake app:pwb:db:seed                                  1 ↵

namespace :pwb do
  namespace :db do
    desc 'Seeds the database with Pwb defaults'
    task seed: [:environment] do
      Pwb::Seeder.seed!
    end
  end
end
