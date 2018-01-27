# page_parts consist of liquid template and block_contents which
# can be parsed to generate html content
# Resulting html content is stored in page content model
module Pwb
  class PagePart < ApplicationRecord
    belongs_to :page, optional: true, foreign_key: "page_slug", primary_key: "slug"

    def as_json(options = nil)
      super({only: [
               "is_rails_part", "page_part_key", "page_slug", "editor_setup", "block_contents"
             ],
             methods: []
             }.merge(options || {}))
    end


    def self.create_from_seed_yml yml_file_name
      # page_parts_dir = Pwb::Engine.root.join('db', 'yml_seeds', 'page_parts')
      page_part_seed_file = Pwb::Engine.root.join('db', 'yml_seeds', 'page_parts', yml_file_name)
      yml_file_contents = YAML.load_file(page_part_seed_file)
      unless Pwb::PagePart.where({page_part_key: yml_file_contents[0]['page_part_key'], page_slug: yml_file_contents[0]['page_slug']}).count > 0
        Pwb::PagePart.create!(yml_file_contents)
      end

    end
  end
end
