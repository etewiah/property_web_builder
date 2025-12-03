# To reload from console:
# load "#{Rails.root}/lib/pwb/pages_seeder.rb"
# Pwb::PagesSeeder.seed_page_content_translations!
#
# Multi-tenancy Support:
# ----------------------
# The pages seeder now supports multi-tenancy by accepting a `website` parameter.
# When seeding pages for a specific tenant:
#
#   website = Pwb::Website.find_by(subdomain: 'my-tenant')
#   Pwb::PagesSeeder.seed_page_basics!(website: website)
#   Pwb::PagesSeeder.seed_page_parts!(website: website)
#
# Pages and PageParts will be associated with the specified website.
# Each website gets its own copy of PageParts to ensure multi-tenant isolation.
#
module Pwb
  class PagesSeeder
    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed_pages
      # sets model entry for each page_part but not actual content
      #
      # @param website [Pwb::Website] The website to seed page parts for (required for multi-tenancy)
      def seed_page_parts!(website: nil)
        @current_website = website || Pwb::Website.first
        raise "Website is required for seeding page parts" unless @current_website
        
        page_parts_dir = Rails.root.join("db", "yml_seeds", "page_parts")

        page_parts_dir.children.each do |file|
          if file.extname == ".yml"
            seed_page_part file
          end
        end
      end

      # Called by this rake task:
      # rake app:pwb:db:seed_pages
      # sets model entry for each page
      #
      # @param website [Pwb::Website] The website to seed pages for (optional)
      def seed_page_basics!(website: nil)
        @current_website = website || Pwb::Website.first
        
        page_yml_filenames = [
          "sell.yml", "about.yml", "buy.yml",
          "rent.yml", "home.yml", "legal_notice.yml",
          "contact.yml", "privacy_policy.yml",
        ]

        page_yml_filenames.each do |page_yml_filename|
          seed_page page_yml_filename
        end
      end

      protected
      
      # Returns the current website being seeded
      def current_website
        @current_website
      end

      def seed_page(yml_file)
        page_seed_file = Rails.root.join("db", "yml_seeds", "pages", yml_file)
        page_yml = YAML.load_file(page_seed_file)
        
        # Find page scoped to the current website
        page_record = current_website.pages.find_by(slug: page_yml[0]["slug"])
        
        unless page_record.present?
          # Create page with website association
          page_record = current_website.pages.create!(page_yml[0])
        end

        # below sets the page title text from I18n translations
        # because setting the value in each page yml for each language
        # is not feasible
        I18n.available_locales.each do |locale|
          title_accessor = "page_title_" + locale.to_s
          # if page_title has not been set for this locale
          next unless page_record.send(title_accessor).blank?
          translation_key = "navbar." + page_record.slug
          # get the I18n translation
          title_value = I18n.t(translation_key, locale: locale, default: nil)
          title_value ||= I18n.t(translation_key, locale: :en, default: "Unknown")
          # in case translation cannot be found
          # take default page_title (English value)
          title_value ||= page_record.page_title
          # set title_value as page_title
          page_record.update_attribute title_accessor, title_value
        end
      end

      def seed_page_part(page_part_seed_file)
        yml_file_contents = YAML.load_file(page_part_seed_file)
        page_part_attrs = yml_file_contents.first
        
        # Check if this page part already exists for this website
        existing = Pwb::PagePart.find_by(
          page_part_key: page_part_attrs["page_part_key"],
          page_slug: page_part_attrs["page_slug"],
          website_id: current_website.id
        )
        
        unless existing
          # Create with website_id for multi-tenant isolation
          Pwb::PagePart.create!(page_part_attrs.merge("website_id" => current_website.id))
        end
      end
    end
  end
end
