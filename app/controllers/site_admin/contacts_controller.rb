# frozen_string_literal: true

module SiteAdmin
  # ContactsController
  # Manages contacts for the current website
  class ContactsController < SiteAdminController
    include SiteAdminIndexable

    indexable_config model: Pwb::Contact,
                     search_columns: %i[primary_email first_name last_name],
                     limit: 100
  end
end
