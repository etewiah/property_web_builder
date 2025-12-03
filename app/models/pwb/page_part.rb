# page_parts consist of liquid template and block_contents which
# can be parsed to generate html content
# Resulting html content is stored in page content model
module Pwb
  class PagePart < ApplicationRecord
    # validate as unique on page_slug and page_part_key???
    belongs_to :page, optional: true, foreign_key: "page_slug", primary_key: "slug"
    belongs_to :website, optional: true
    # as well as belonging to pages, can be used by website (for footer html etc)

    after_save :clear_template_cache
    after_destroy :clear_template_cache

    def as_json(options = nil)
      super({ only: [
        "is_rails_part", "page_part_key", "page_slug", "editor_setup", "block_contents", "show_in_editor", "id", "order_in_editor",
      ],
             methods: [] }.merge(options || {}))
    end

    def self.create_from_seed_yml(yml_file_name)
      # page_parts_dir = Rails.root.join('db', 'yml_seeds', 'page_parts')
      page_part_seed_file = Rails.root.join("db", "yml_seeds", "page_parts", yml_file_name)
      yml_file_contents = YAML.load_file(page_part_seed_file)
      unless Pwb::PagePart.where({ page_part_key: yml_file_contents[0]["page_part_key"], page_slug: yml_file_contents[0]["page_slug"] }).count > 0
        Pwb::PagePart.create!(yml_file_contents)
      end
    end

    # Get template content with fallback to file system
    # Priority: 1) Database, 2) Theme-specific file, 3) Default file
    def template_content
      cache_key = "page_part/#{id}/#{page_part_key}/#{website&.theme_name}/template"

      Rails.cache.fetch(cache_key, expires_in: cache_duration) do
        load_template_content
      end
    end

    private

    def cache_duration
      # Short cache in development for rapid iteration
      # Long cache in production for performance
      Rails.env.development? ? 5.seconds : 1.hour
    end

    def load_template_content
      # 1. Database Override (highest priority)
      return self[:template] if self[:template].present?

      theme_name = website&.theme_name || "default"

      # 2. Theme-Specific File
      theme_path = Rails.root.join("app/themes/#{theme_name}/page_parts/#{page_part_key}.liquid")
      return File.read(theme_path) if File.exist?(theme_path)

      # 3. Default File
      default_path = Rails.root.join("app/views/pwb/page_parts/#{page_part_key}.liquid")
      return File.read(default_path) if File.exist?(default_path)

      # 4. Fallback to empty string if nothing found
      ""
    end

    def clear_template_cache
      cache_key = "page_part/#{id}/#{page_part_key}/#{website&.theme_name}/template"
      Rails.cache.delete(cache_key)
    end
  end
end
