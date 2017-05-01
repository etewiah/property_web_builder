module Pwb
  class Seeder
    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed                                  1 ↵

      def seed!
        I18n.locale = :en

        # unless ENV["RAILS_ENV"] == "test"
        #   load File.join(Pwb::Engine.root, 'db', 'seeds', 'translations.rb')
        # end
        unless I18n::Backend::ActiveRecord::Translation.all.length > 10
          load File.join(Pwb::Engine.root, 'db', 'seeds', 'translations_en.rb')
          load File.join(Pwb::Engine.root, 'db', 'seeds', 'translations_es.rb')
        end

        seed_content 'content_columns.yml'
        seed_content 'carousel.yml'
        seed_content 'about_us.yml'
        seed_content 'static.yml'
        seed_content 'footer.yml'
        seed_content 'sell.yml'
        seed_agency 'agency.yml'
        seed_website 'website.yml'
        # need to seed website first so correct currency is used
        seed_prop 'villa_for_sale.yml'
        seed_prop 'villa_for_rent.yml'
        seed_prop 'flat_for_sale.yml'
        seed_prop 'flat_for_rent.yml'
        seed_sections 'sections.yml'
        seed_field_keys 'field_keys.yml'
        seed_users 'users.yml'
      end

      protected

      def seed_users yml_file
        users_yml = load_seed_yml yml_file
        users_yml.each do |user_yml|
          unless Pwb::User.where(email: user_yml['email']).count > 0
            Pwb::User.create!(user_yml)
          end
        end
      end

      def seed_field_keys yml_file
        field_keys_yml = load_seed_yml yml_file
        field_keys_yml.each do |field_key_yml|
          unless Pwb::FieldKey.where(global_key: field_key_yml['global_key']).count > 0
            Pwb::FieldKey.create!(field_key_yml)
          end
        end
      end

      def seed_sections yml_file
        sections_yml = load_seed_yml yml_file
        sections_yml.each do |single_section_yml|
          unless Pwb::Section.where(link_key: single_section_yml['link_key']).count > 0
            Pwb::Section.create!(single_section_yml)
          end
        end
      end

      def seed_website yml_file
        website_yml = load_seed_yml yml_file
        website = Pwb::Website.unique_instance
        unless website.company_display_name.present?
          website.update!(website_yml)
        end
      end

      def seed_agency yml_file
        agency_yml = load_seed_yml yml_file
        agency = Pwb::Agency.unique_instance
        unless agency.display_name.present?
          agency.update!(agency_yml)
          agency_address_yml = load_seed_yml 'agency_address.yml'
          agency_address = Pwb::Address.create!(agency_address_yml)
          agency.primary_address = agency_address
          agency.save!
        end
      end

      def seed_prop yml_file
        prop_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'prop', yml_file)
        prop_yml = YAML.load_file(prop_seed_file)
        prop_yml.each do |single_prop_yml|
          unless Pwb::Prop.where(reference: single_prop_yml['reference']).count > 0
            photos = []
            if single_prop_yml["photo_urls"].present?
              photos = create_photos_from_urls single_prop_yml["photo_urls"], Pwb::PropPhoto
              single_prop_yml.except! "photo_urls"
            end
            if single_prop_yml["photo_files"].present?
              photos = create_photos_from_files single_prop_yml["photo_files"], Pwb::PropPhoto
              single_prop_yml.except! "photo_files"
            end
            new_prop = Pwb::Prop.create!(single_prop_yml)
            if photos.length > 0
              photos.each do |photo|
                new_prop.prop_photos.push photo
              end
            end
          end
        end
      end

      def seed_content yml_file
        content_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'content', yml_file)
        content_yml = YAML.load_file(content_seed_file)
        # tag is used to group content for an admin page
        # key is camelcase (js style) - used client side to identify each item in a group of content
        content_yml.each do |single_content_yml|
          # check content does not already exist
          unless Pwb::Content.where(key: single_content_yml['key']).count > 0
            photos = []
            if single_content_yml["photo_urls"].present?
              photos = create_photos_from_urls single_content_yml["photo_urls"], Pwb::ContentPhoto
              single_content_yml.except! "photo_urls"
            end
            if single_content_yml["photo_files"].present?
              photos = create_photos_from_files single_content_yml["photo_files"], Pwb::ContentPhoto
              single_content_yml.except! "photo_files"
            end
            new_content = Pwb::Content.create!(single_content_yml)
            if photos.length > 0
              photos.each do |photo|
                new_content.content_photos.push photo
              end
            end
          end
        end
      end

      def create_photos_from_files photo_files, photo_class
        photos = []
        if ENV["RAILS_ENV"] == "test"
          # don't create photos for tests
          return photos
        end
        photo_files.each do |photo_file|
          begin
            photo = photo_class.send('create')
            photo.image = Pwb::Engine.root.join(photo_file).open
            photo.save!
            photos.push photo
          rescue Exception => e
            # log exception to console
            p e
            if photo
              photo.destroy!
            end
          end
        end
        return photos
      end

      def create_photos_from_urls photo_urls, photo_class
        photos = []
        if ENV["RAILS_ENV"] == "test"
          # don't create photos for tests
          return photos
        end
        photo_urls.each do |photo_url|
          begin
            photo = photo_class.send('create')
            photo.remote_image_url = photo_url
            photo.save!
            photos.push photo
          rescue Exception => e
            if photo
              photo.destroy!
            end
          end
        end
        return photos
      end

      def load_seed_yml yml_file
        seed_file = Pwb::Engine.root.join('db', 'yml_seeds', yml_file)
        yml = YAML.load_file(seed_file)
      end

    end
  end
end
