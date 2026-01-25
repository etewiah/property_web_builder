# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Seed client themes (A themes for Astro rendering)"
    task client_themes: :environment do
      load Rails.root.join('db/seeds/client_themes.rb')
    end
  end
end
