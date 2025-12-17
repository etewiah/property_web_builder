# frozen_string_literal: true

module SiteAdmin
  # MessagesController
  # Manages messages for the current website
  class MessagesController < SiteAdminController
    include SiteAdminIndexable

    indexable_config model: Pwb::Message,
                     search_columns: %i[origin_email content],
                     limit: 100
  end
end
