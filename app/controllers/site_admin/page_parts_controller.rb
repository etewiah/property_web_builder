# frozen_string_literal: true

module SiteAdmin
  # PagePartsController
  # Manages page parts for the current website
  class PagePartsController < SiteAdminController
    include SiteAdminIndexable

    indexable_config model: Pwb::PagePart,
                     search_columns: %i[page_part_key],
                     includes: [:page]
  end
end
