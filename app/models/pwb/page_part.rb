# page_parts consist of liquid template and block_contents which 
# can be parsed to generate html content
# Resulting html content is stored in page content model
module Pwb
  class PagePart < ApplicationRecord
    belongs_to :page, foreign_key: "page_slug", primary_key: "slug"
  end
end
