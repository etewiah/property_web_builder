module Pwb
  class Seeder
    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed                                  1 ↵

      def seed!
        I18n.locale = :en
        # tag is used to group content for an admin page
        # key is camelcase (js style) - used client side to identify each item in a group of content
        # seed_content 'content_columns.yml'
        seed_content 'carousel.yml'
        # seed_content 'about_us.yml'
        seed_prop 'villa_for_sale.yml'
        seed_prop 'villa_for_rent.yml'
        seed_prop 'flat_for_sale.yml'
        seed_agency 'agency.yml'
        seed_sections 'sections.yml'
        seed_field_keys 'field_keys.yml'
        seed_users 'users.yml'
        load File.join(Pwb::Engine.root, 'db', 'seeds', 'translations.rb')
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

      def seed_agency yml_file
        agency_yml = load_seed_yml yml_file
        unless Pwb::Agency.count > 0
          agency_yml.each do |single_agency_yml|
            Pwb::Agency.create!(single_agency_yml)
          end
        end
      end

      def seed_prop yml_file
        prop_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'prop', yml_file)
        prop_yml = YAML.load_file(prop_seed_file)
        prop_yml.each do |single_prop_yml|
          unless Pwb::Prop.where(reference: single_prop_yml['reference']).count > 0
            Pwb::Prop.create!(single_prop_yml)
          end
        end
      end

      def seed_content yml_file
        content_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'content', yml_file)
        content_yml = YAML.load_file(content_seed_file)
        content_yml.each do |single_content_yml|
          unless Pwb::Content.where(key: single_content_yml['key']).count > 0
            if single_content_yml["photo_url"].present?
              content_photo = create_content_photo single_content_yml["photo_url"]
              single_content_yml.except! "photo_url"
            end
            new_content = Pwb::Content.create!(single_content_yml)
            if content_photo
              new_content.content_photos.push content_photo
            end
          end
        end
      end

      def create_content_photo photo_url
        begin
          content_photo = Pwb::ContentPhoto.create
          content_photo.remote_image_url = photo_url
          content_photo.save!
          return content_photo
        rescue 
          if content_photo
            content_photo.destroy!
            return nil
          end
        end
      end

      def load_seed_yml yml_file
        seed_file = Pwb::Engine.root.join('db', 'yml_seeds', yml_file)
        yml = YAML.load_file(seed_file)
      end

    end
  end
end
