# frozen_string_literal: true

module SiteAdmin
  # UsersController
  # Manages users for the current website
  class UsersController < SiteAdminController
    include SiteAdminIndexable

    indexable_config model: Pwb::User,
                     search_columns: %i[email]
  end
end
