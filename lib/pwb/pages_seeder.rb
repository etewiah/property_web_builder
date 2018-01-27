# To reload from console:
# load "#{Pwb::Engine.root}/lib/pwb/pages_seeder.rb"
# Pwb::PagesSeeder.seed_page_content_translations!
module Pwb
  class PagesSeeder
    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed_pages
      # sets model entry for each page_part but not actual content
      def seed_page_parts!
        page_parts_dir = Pwb::Engine.root.join('db', 'yml_seeds', 'page_parts')

        page_parts_dir.children.each do |file|
          if file.extname == ".yml"
            seed_page_part file
          end
        end
      end

      # Called by this rake task:
      # rake app:pwb:db:seed_pages
      # sets model entry for each page
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

      protected


      def seed_page(yml_file)
        page_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'pages', yml_file)
        page_yml = YAML.load_file(page_seed_file)
        # unless Pwb::Page.where(slug: page_yml[0]['slug']).count > 0
        #   Pwb::Page.create!(page_yml)
        # end

        page_record = Pwb::Page.find_by_slug(page_yml[0]['slug'])
        # unless Pwb::Page.where(slug: page_yml[0]['slug']).count > 0
        unless page_record.present?
          page_record = Pwb::Page.create!(page_yml[0])
        end


        # below sets the page title text from I18n translations
        # because setting the value in each page yml for each language
        # is not feasible
        I18n.available_locales.each do |locale|
          title_accessor = 'page_title_' + locale.to_s
          # if page_title has not been set for this locale
          next unless page_record.send(title_accessor).blank?
          translation_key = 'navbar.' + page_record.slug
          # get the I18n translation
          title_value = I18n.t(translation_key, locale: locale, default: nil)
          title_value ||= I18n.t(translation_key, locale: :en, default: 'Unknown')
          # in case translation cannot be found
          # take default page_title (English value)
          title_value ||= page_record.page_title
          # set title_value as page_title
          page_record.update_attribute title_accessor, title_value
        end
      end

      def seed_page_part(page_part_seed_file)
        Pwb::PagePart.create_from_seed_yml page_part_seed_file.basename.to_s
        # yml_file_contents = YAML.load_file(page_part_seed_file)
        # byebug
        # unless Pwb::PagePart.where({page_part_key: yml_file_contents[0]['page_part_key'], page_slug: yml_file_contents[0]['page_slug']}).count > 0
        #   Pwb::PagePart.create!(yml_file_contents)
        # end
      end

    end
  end
end
