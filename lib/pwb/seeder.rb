module Pwb
  class Seeder

    class << self
      # Called by this rake task:
      # rake app:pwb:db:seed                                  1 ↵
      #
      def seed!

        I18n.locale = :en
        # tag is used to group content for an admin page
        # key is camelcase (js style) - used client side to identify each item in a group of content

        seed_example_carousel
        seed_example_content_cols

      end

      protected

      def seed_example_carousel
        carousel_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'content', 'carousel.yml')
        carousel_yml = YAML.load_file(carousel_seed_file)
        carousel_yml.each do |content_col_yml|
          unless Pwb::Content.where(key: content_col_yml["key"]).count > 0
            Pwb::Content.create!(content_col_yml)
          end
        end
      end

      def seed_example_content_cols
        content_cols_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'content', 'content_columns.yml')
        content_cols_yml = YAML.load_file(content_cols_seed_file)
        content_cols_yml.each do |content_col_yml|
          unless Pwb::Content.where(key: content_col_yml["key"]).count > 0
            Pwb::Content.create!(content_col_yml)
          end
        end
      end

    end
  end
end
