module Pwb
  class PageContent < ApplicationRecord
    belongs_to :page
    belongs_to :content
  end
end
