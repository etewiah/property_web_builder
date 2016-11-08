module Pwb
  class Seeder

    class << self
      # Call this from your +db/seeds.rb+ file with the `rake db:seed task'.
      #
      def seed!

        I18n.locale = :en
        # tag is used to group content for an admin page
        # key is camelcase (js style) - used client side to identify each item in a group of content
        unless Pwb::Content.where(tag: "landing-carousel").count > 1
          Pwb::Content.create!(
            [
              { key: 'landingPageHero',
                tag: 'landing-carousel',
                raw_es: '
                        <span class="subtitle-sm">Somos lo mejor.</span>
                        <ul class="list-carousel mb-20">
                          <li><i class="fa fa-check-square"></i>Nuestro equipo está formado por profesionales</li>
                        </ul>',
                raw_en: '
                        <span class="subtitle-sm">We are the best estate agents in our area.</span>
                        <ul class="list-carousel mb-20">
                          <li><i class="fa fa-check-square"></i> Professional staff</li>
                          <li><i class="fa fa-check-square"></i> We will find you the best property on the market</li>
                        </ul>' 
                }
          ])
        end


        # create_default_site
        # if create_root_page
        #   try_seed_pages
        # elsif page_seeds_file.file?
        #   desc "Seeding Alchemy pages"
        #   log "There are already pages present in your database. " \
        #       "Please use `rake db:reset' if you want to rebuild your database.", :skip
        # end
        # seed_users if user_seeds_file.file?
      end

      protected

    end
  end
end
