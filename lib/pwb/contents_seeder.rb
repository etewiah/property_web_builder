# To reload from console:
# load "#{Rails.root}/lib/pwb/contents_seeder.rb"
# Pwb::ContentsSeeder.seed_page_content_translations!
#
# Multi-tenancy Support:
# ----------------------
# The contents seeder now supports multi-tenancy by accepting a `website` parameter.
# When seeding content for a specific tenant:
#
#   website = Pwb::Website.find_by(subdomain: 'my-tenant')
#   Pwb::ContentsSeeder.seed_page_content_translations!(website: website)
#
# Content will be associated with the specified website's pages.
#
module Pwb
  class ContentsSeeder
    class << self

      # Called by this rake task:
      # rake app:pwb:db:seed_pages
      # sets actual content for each page based on its page_parts
      # below need to have page_parts populated to work correctly
      #
      # @param website [Pwb::Website] The website to seed content for (optional)
      def seed_page_content_translations!(website: nil)
        @current_website = website || Pwb::Website.unique_instance
        
        I18n.available_locales.each do |locale|
          locale_seed_file = Rails.root.join("db", "yml_seeds", "content_translations", locale.to_s + ".yml")
          if File.exist? locale_seed_file
            yml = YAML.load_file(locale_seed_file)

            seed_content_for_locale locale.to_s, yml
          else
            puts "Contents seed for #{locale} not found"
          end
        end
      end

      # def seed_rails_parts
      #   contact_us_page = Pwb::Page.find_by_slug "contact-us"
      #   contact_us_rails_part = contact_us_page.page_contents.find_or_create_by(label: "contact_us__form_and_map")
      # end

      protected
      
      # Returns the current website being seeded
      def current_website
        @current_website
      end

      def seed_content_for_locale(locale, yml)
        # Use the current website being seeded
        current_website.page_parts.each do |page_part|
          page_part_key = page_part.page_part_key

          page_part_manager = Pwb::PagePartManager.new page_part_key, current_website
          set_page_part_content yml, page_part_key, page_part_manager, "website", locale
        end

        # Only seed content for pages belonging to the current website
        current_website.pages.each do |page|
          page.page_parts.each do |page_part|
            page_part_key = page_part.page_part_key
            page_part_manager = Pwb::PagePartManager.new page_part_key, page

            # if page_part.is_rails_part
            #   page_part_manager.find_or_create_join_model
            # else
            # end
            set_page_part_content yml, page_part_key, page_part_manager, page.slug, locale
            page_part_manager.set_default_page_content_order_and_visibility
          end
        end
      end

      # reads content from
      def set_page_part_content(yml, page_part_key, page_part_manager, container_label, locale)

        # Items in each locale seed file are nested as
        # page_slug/page_part_key and then the block labels

        if yml[locale] && yml[locale][container_label] && yml[locale][container_label][page_part_key]
          seed_content = yml[locale][container_label][page_part_key]
          page_part_manager.seed_container_block_content locale, seed_content
          p "#{container_label} #{page_part_key} content set for #{locale}."
        else
          # Might get here because the page_part is_rails_part or
          # does not have any content to be seeded.
          # Still want to have a page_content entry based on that
          # page_part though
          page_part_manager.find_or_create_join_model
          p "no content for #{container_label} page #{page_part_key} #{locale}."
        end
      end
    end
  end
end
