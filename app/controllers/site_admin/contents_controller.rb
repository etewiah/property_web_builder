# frozen_string_literal: true

module SiteAdmin
  # ContentsController
  # Manages web contents for the current website
  class ContentsController < SiteAdminController
    include SiteAdminIndexable

    indexable_config model: Pwb::Content,
                     search_columns: %i[tag]
  end
end
