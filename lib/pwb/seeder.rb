module Pwb
  class Seeder
    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed                                  1 ↵

      def seed!
        I18n.locale = :en
        # tag is used to group content for an admin page
        # key is camelcase (js style) - used client side to identify each item in a group of content
        seed_content 'content_columns.yml'
        seed_content 'carousel.yml'
        seed_content 'about_us.yml'
        seed_prop 'villa_for_sale.yml'
        seed_agency 'agency.yml'
        seed_sections 'sections.yml'
      end

      protected

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
            Pwb::Content.create!(single_content_yml)
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
