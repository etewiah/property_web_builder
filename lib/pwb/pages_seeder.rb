# To reload from console:
# load "#{Pwb::Engine.root}/lib/pwb/pages_seeder.rb"
module Pwb
  class PagesSeeder
    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed_pages                                  1 ↵
      def seed_page_parts!
        page_part_yml_filenames = [
          "about-us__our_agency.yml", "about-us__content_html.yml",
          "contact-us__form_and_map.yml", "contact-us__content_html.yml",
          "home__landing_hero.yml", "home__about_us_services.yml", "home__content_html.yml",
          "sell__content_html.yml",
          "privacy__content_html.yml", "legal__content_html.yml"
        ]

        page_part_yml_filenames.each do |filename|
          seed_page_part filename
        end
      end


      def seed_page_content_translations!
        I18n.available_locales.each do |locale|
          seed_content_for_locale locale.to_s
        end
      end

      def seed_page_basics!
        page_yml_filenames = [
          "sell.yml", "about.yml", "buy.yml",
          "rent.yml", "home.yml", "legal_notice.yml",
          "contact.yml", "privacy_policy.yml"
        ]

        page_yml_filenames.each do |page_yml_filename|
          seed_page page_yml_filename
        end
      end


      # def seed_rails_parts
      #   contact_us_page = Pwb::Page.find_by_slug "contact-us"
      #   contact_us_rails_part = contact_us_page.page_contents.find_or_create_by(label: "contact_us__form_and_map")        
      # end

      protected


      def seed_page yml_file
        page_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'pages', yml_file)
        page_yml = YAML.load_file(page_seed_file)
        unless Pwb::Page.where(slug: page_yml[0]['slug']).count > 0
          Pwb::Page.create!(page_yml)
        end
      end


      def seed_page_part yml_file
        lf_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'page_parts', yml_file)
        lf_yml = YAML.load_file(lf_seed_file)
        unless Pwb::PagePart.where({fragment_key: lf_yml[0]['fragment_key'],page_slug: lf_yml[0]['page_slug']}).count > 0
          Pwb::PagePart.create!(lf_yml)
        end
      end

      def seed_content_for_locale locale
        locale_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'content_translations', locale + '.yml')
        unless File.exist? locale_seed_file
          return
        end
        yml = YAML.load_file(locale_seed_file)

        Pwb::Page.all.each do |page|
          page.page_parts.each do |page_part|
            fragment_key = page_part.fragment_key
            # Items in each locale seed file are nested as
            # page_slug/fragment_key and then the block labels
            unless yml[locale] && yml[locale][page.slug] && yml[locale][page.slug][fragment_key]
              # skip if there is no content to populate
              next
            end
            if yml[locale][page.slug][fragment_key]
              seed_content = yml[locale][page.slug][fragment_key]
              set_page_block_content locale, page_part, seed_content
            end
          end
        end

        # Pwb::PageSetup.all.each do |page_setup|
        #   page_setup.pages.each do |page|
        #     page_setup.fragment_configs.each do |fragment_config|
        #       fragment_label = fragment_config["label"]
        #       # Items in each locale seed file are nested as
        #       # page_slug/fragment_label and then the block labels
        #       unless yml[locale] && yml[locale][page.slug] && yml[locale][page.slug][fragment_label]
        #         # skip if there is no content to populate
        #         next
        #       end
        #       if yml[locale][page.slug][fragment_label]
        #         set_page_block_content locale, page.slug, fragment_config, yml[locale][page.slug][fragment_label]
        #       end
        #     end
        #   end
        # end

      end

      def set_page_block_content locale, page_part, seed_content
        unless page_part.editor_setup
          binding.pry
          return
        end

        fragment_config = page_part.editor_setup

        page = page_part.page
        # Pwb::Page.find_by_slug page_part
        # fragment_label uniquely identifies a fragment
        # and is also the name of the corresponding partial
        fragment_label = page_part.fragment_key


        # ensure path exists in details col of page
        # unless page.details["fragments"].present?
        #   page.details["fragments"] = {}
        # end
        # unless page.details["fragments"][fragment_label].present?
        #   page.details["fragments"][fragment_label] = {}
        # end

        # container for json to be attached to page details
        content_for_pf_locale = {"blocks" => {}}
        # {"blocks"=>{"title_a"=>{"content"=>"about our agency"}, "content_a"=>{"content"=>""}}}
        fragment_config["editorBlocks"].each do |configColBlocks|
          configColBlocks.each do |configRowBlock|
            row_block_label = configRowBlock["label"]
            row_block_content = ""
            # find the content for current block from within the seed content
            if seed_content[row_block_label]
              if configRowBlock["isImage"]
                photo = page.seed_fragment_photo fragment_label, row_block_label, seed_content[row_block_label]
                if photo.present? && photo.optimized_image_url.present?
                  # optimized_image_url is defined in content_photo and will
                  # return cloudinary url or filesystem url depending on settings
                  row_block_content = photo.optimized_image_url
                else
                  row_block_content = "http://via.placeholder.com/350x250"
                end
              else
                row_block_content = seed_content[row_block_label]
              end
            end
            content_for_pf_locale["blocks"][row_block_label] = {"content"=>row_block_content}
          end
        end


        # save the block contents (in associated page_part model)
        updated_details = page.set_page_part_block_contents fragment_label, locale, content_for_pf_locale
        # retrieve the contents saved above and use to rebuild html for that page_part
        # (and save it in associated page_content model)
        fragment_html = page.rebuild_page_content fragment_label, locale


        # fragment_html = page.parse_page_part fragment_label, content_for_pf_locale


        # # and save in content model associated with page
        # content_for_page = page.set_fragment_html fragment_label, locale, fragment_html

        sort_order = fragment_config["default_sort_order"] || 1
        page.set_fragment_sort_order fragment_label, sort_order



        visible_on_page = false
        if fragment_config["default_visible_on_page"]
          visible_on_page = true
        end

        page.set_fragment_visibility fragment_label, visible_on_page

        # content_for_page.save!

        # page.details["fragments"][fragment_label][locale] = content_for_pf_locale
        # page.save!

        p "#{page.slug} page #{fragment_label} content set for #{locale}."
      end

    end
  end
end
