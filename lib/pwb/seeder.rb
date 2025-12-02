# To reload from console:
# load "#{Rails.root}/lib/pwb/seeder.rb"
#
# Multi-tenancy Support:
# ----------------------
# The seeder now supports multi-tenancy by accepting a `website` parameter.
# When seeding for a specific tenant, pass the website instance:
#
#   website = Pwb::Website.find_by(subdomain: 'my-tenant')
#   Pwb::Seeder.seed!(website: website)
#
# If no website is provided, it defaults to the first website in the database.
#
# Data that is scoped to a website (props, links, agency) will be associated
# with the provided website. Shared data (translations, users, field_keys)
# is only seeded once.
#
# Optional Property Seeding:
# --------------------------
# By default, sample properties are seeded. To skip property seeding:
#
#   Pwb::Seeder.seed!(website: website, skip_properties: true)
#
# This is useful for production environments where you don't want demo data.
#
module Pwb
  class Seeder
    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed                                  1 ↵
      #
      # @param website [Pwb::Website] The website to seed data for (optional)
      # @param skip_properties [Boolean] If true, skip seeding sample properties (default: false)
      def seed!(website: nil, skip_properties: false)
        @current_website = website || Pwb::Website.first || Pwb::Website.create!(theme_name: 'bristol')
        @skip_properties = skip_properties
        
        I18n.locale = :en
        # unless ENV["RAILS_ENV"] == "test"
        #   load File.join(Rails.root, 'db', 'seeds', 'translations.rb')
        # end
        # In test environment, always reload translations
        # In other environments, only load if count is low
        should_load_translations = ENV["RAILS_ENV"] == "test" || I18n::Backend::ActiveRecord::Translation.all.length <= 600
        if should_load_translations
          # TODO: look in a directory and load all the files there
          load File.join(Rails.root, "db", "seeds", "translations_ca.rb")
          load File.join(Rails.root, "db", "seeds", "translations_en.rb")
          load File.join(Rails.root, "db", "seeds", "translations_es.rb")
          load File.join(Rails.root, "db", "seeds", "translations_de.rb")
          load File.join(Rails.root, "db", "seeds", "translations_fr.rb")
          load File.join(Rails.root, "db", "seeds", "translations_it.rb")
          load File.join(Rails.root, "db", "seeds", "translations_nl.rb")
          load File.join(Rails.root, "db", "seeds", "translations_pl.rb")
          load File.join(Rails.root, "db", "seeds", "translations_pt.rb")
          load File.join(Rails.root, "db", "seeds", "translations_ro.rb")
          load File.join(Rails.root, "db", "seeds", "translations_ru.rb")
          load File.join(Rails.root, "db", "seeds", "translations_ko.rb")
          load File.join(Rails.root, "db", "seeds", "translations_bg.rb")
        end

        # seed_sections 'sections.yml'
        # seed_content 'content_columns.yml'
        # seed_content 'carousel.yml'
        # seed_content 'about_us.yml'
        # seed_content 'static.yml'
        # seed_content 'footer.yml'
        # seed_content 'sell.yml'
        seed_agency "agency.yml"
        # need to seed website first so correct currency is used
        seed_website "website.yml"
        # currency passed in for properties is ignored in favour
        # of default website currency
        seed_properties unless @skip_properties
        seed_field_keys "field_keys.yml"
        seed_users "users.yml"
        seed_contacts "contacts.yml"
        # seed_pages
        seed_links "links.yml"
      end

      protected
      
      # Returns the current website being seeded
      def current_website
        @current_website
      end
      
      # Seeds sample properties for the current website
      # Only seeds if the website has fewer than 4 properties
      def seed_properties
        unless @current_website.props.count > 3
          puts "   🏠 Seeding sample properties..."
          seed_prop "villa_for_sale.yml"
          seed_prop "villa_for_rent.yml"
          seed_prop "flat_for_sale.yml"
          seed_prop "flat_for_rent.yml"
          seed_prop "flat_for_sale_2.yml"
          seed_prop "flat_for_rent_2.yml"
        end
      end

      def seed_contacts(yml_file)
        contacts_yml = load_seed_yml yml_file
        contacts_yml.each do |contact_yml|
          unless Pwb::Contact.where(primary_email: contact_yml["email"]).count > 0
            Pwb::Contact.create!(contact_yml)
          end
        end
      end

      def seed_users(yml_file)
        users_yml = load_seed_yml yml_file
        users_yml.each do |user_yml|
          unless Pwb::User.where(email: user_yml["email"]).count > 0
            # Ensure website association if required
            if Pwb::User.reflect_on_association(:website)
              user_yml["website_id"] ||= @current_website.id if @current_website
            end
            Pwb::User.create!(user_yml)
          end
        end
      end

      def seed_field_keys(yml_file)
        field_keys_yml = load_seed_yml yml_file
        field_keys_yml.each do |field_key_yml|
          unless Pwb::FieldKey.where(global_key: field_key_yml["global_key"]).count > 0
            Pwb::FieldKey.create!(field_key_yml)
          end
        end
      end

      def seed_links(yml_file)
        links_yml = load_seed_yml yml_file
        links_yml.each do |single_link_yml|
          # Check if this link already exists for this website
          link_record = current_website.links.find_by(slug: single_link_yml["slug"])
          
          unless link_record.present?
            # Create link with website association
            link_record = current_website.links.create!(single_link_yml)
          end

          # below sets the link title text from I18n translations
          # because setting the value in links.yml for each language
          # is not feasible
          I18n.available_locales.each do |locale|
            title_accessor = "link_title_" + locale.to_s
            # if link_title has not been set for this locale
            next unless link_record.send(title_accessor).blank?
            # if link is associated with a page
            if single_link_yml["page_slug"]
              translation_key = "navbar." + single_link_yml["page_slug"]
              # get the I18n translation
              title_value = I18n.t(translation_key, locale: locale, default: nil)
              title_value ||= I18n.t(translation_key, locale: :en, default: "Unknown")
            end
            # in case translation cannot be found or link not associated with a page
            # take default link_title (English value)
            title_value ||= link_record.link_title
            # set title_value as link_title
            link_record.update_attribute title_accessor, title_value
          end
        end
      end

      def seed_website(yml_file)
        website_yml = load_seed_yml yml_file
        # Use the current website being seeded
        website = current_website
        unless website.company_display_name.present?
          website.update!(website_yml)
        end
      end

      def seed_agency(yml_file)
        agency_yml = load_seed_yml yml_file
        # Find or create agency for the current website
        agency = current_website.agency || current_website.build_agency
        unless agency.display_name.present?
          agency.update!(agency_yml)
          agency_address_yml = load_seed_yml "agency_address.yml"
          agency_address = Pwb::Address.create!(agency_address_yml)
          agency.primary_address = agency_address
          agency.save!
          # Associate agency with website if not already
          current_website.update!(agency: agency) unless current_website.agency
        end
      end

      def seed_prop(yml_file)
        prop_seed_file = Rails.root.join("db", "yml_seeds", "prop", yml_file)
        prop_yml = YAML.load_file(prop_seed_file)
        prop_yml.each do |single_prop_yml|
          # Check if prop exists for this website
          next if current_website.props.where(reference: single_prop_yml["reference"]).count > 0
          
          photos = []
          if single_prop_yml["photo_urls"].present?
            photos = create_photos_from_urls single_prop_yml["photo_urls"], Pwb::PropPhoto
            single_prop_yml.except! "photo_urls"
          end
          if single_prop_yml["photo_files"].present?
            photos = create_photos_from_files single_prop_yml["photo_files"], Pwb::PropPhoto
            single_prop_yml.except! "photo_files"
          end
          # Create prop with website association
          new_prop = current_website.props.create!(single_prop_yml)
          next unless !photos.empty?
          photos.each do |photo|
            new_prop.prop_photos.push photo
          end
        end
      end

      # def seed_content(yml_file)
      #   content_seed_file = Rails.root.join('db', 'yml_seeds', yml_file)
      #   content_yml = YAML.load_file(content_seed_file)
      #   # tag is used to group content for an admin page
      #   # key is camelcase (js style) - used client side to identify each item in a group of content
      #   content_yml.each do |single_content_yml|
      #     # check content does not already exist
      #     next if Pwb::Content.where(key: single_content_yml['key']).count > 0
      #     photos = []
      #     if single_content_yml["photo_urls"].present?
      #       photos = create_photos_from_urls single_content_yml["photo_urls"], Pwb::ContentPhoto
      #       single_content_yml.except! "photo_urls"
      #     end
      #     if single_content_yml["photo_files"].present?
      #       photos = create_photos_from_files single_content_yml["photo_files"], Pwb::ContentPhoto
      #       single_content_yml.except! "photo_files"
      #     end
      #     new_content = Pwb::Content.create!(single_content_yml)
      #     next unless !photos.empty?
      #     photos.each do |photo|
      #       new_content.content_photos.push photo
      #     end
      #   end
      #   print("success!")
      # end

      def create_photos_from_files(photo_files, photo_class)
        photos = []
        if ENV["RAILS_ENV"] == "test"
          # don't create photos for tests
          return photos
        end
        photo_files.each do |photo_file|
          begin
            photo = photo_class.send("create")
            file_path = Rails.root.join(photo_file)

            # Use ActiveStorage attach method
            photo.image.attach(
              io: file_path.open,
              filename: File.basename(photo_file),
              content_type: get_content_type(photo_file)
            )

            photo.save!
            photos.push photo
            puts "Successfully created photo from #{photo_file}"
            sleep 1
          rescue Exception => e
            # log exception to console
            puts "Failed to create photo from #{photo_file}"
            puts e
            if photo
              photo.destroy!
            end
          end
        end
        photos
      end

      def create_photos_from_urls(photo_urls, photo_class)
        photos = []
        if ENV["RAILS_ENV"] == "test"
          # don't create photos for tests
          return photos
        end
        photo_urls.each do |photo_url|
          begin
            photo = photo_class.send("create")

            # For URLs, we need to download the file first
            require 'open-uri'
            downloaded_image = URI.open(photo_url)

            photo.image.attach(
              io: downloaded_image,
              filename: File.basename(photo_url),
              content_type: get_content_type_from_url(photo_url)
            )

            photo.save!
            photos.push photo
            puts "Successfully created photo from #{photo_url}"
          rescue Exception => e
            puts "Failed to create photo from #{photo_url}"
            puts e
            if photo
              photo.destroy!
            end
          end
        end
        photos
      end

      def load_seed_yml(yml_file)
        seed_file = Rails.root.join("db", "yml_seeds", yml_file)
        yml = YAML.load_file(seed_file)
      end

      # Helper method to determine content type from file extension
      def get_content_type(file_path)
        case File.extname(file_path).downcase
        when '.jpg', '.jpeg'
          'image/jpeg'
        when '.png'
          'image/png'
        when '.gif'
          'image/gif'
        when '.webp'
          'image/webp'
        else
          'application/octet-stream'
        end
      end

      # Helper method to determine content type from URL
      def get_content_type_from_url(url)
        case File.extname(URI.parse(url).path).downcase
        when '.jpg', '.jpeg'
          'image/jpeg'
        when '.png'
          'image/png'
        when '.gif'
          'image/gif'
        when '.webp'
          'image/webp'
        else
          'image/jpeg' # Default for images
        end
      end
    end
  end
end
